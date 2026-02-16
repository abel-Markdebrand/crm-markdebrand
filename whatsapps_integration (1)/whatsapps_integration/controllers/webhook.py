# -*- coding: utf-8 -*-
from odoo import http
from odoo.http import request
import json
import logging
import base64

_logger = logging.getLogger(__name__)

class EvolutionWebhook(http.Controller):
    
    @http.route('/whatsapp/evolution/webhook', type='http', auth='public', methods=['POST'], csrf=False)
    def evolution_webhook(self, **kwargs):
        """Handle incoming Evolution API webhooks."""
        _logger.info("Received Evolution Webhook (HTTP)")
        
        try:
            # Parse standard JSON payload
            data = json.loads(request.httprequest.data)
        except Exception as e:
            _logger.error("Failed to parse webhook JSON: %s", str(e))
            return request.make_response(json.dumps({'error': 'bad_json'}), headers=[('Content-Type', 'application/json')])
        
        # Robust event type extraction
        event_type = data.get('type') or data.get('event')
        _logger.info("Webhook Event Type: %s", event_type)
        
        if event_type != 'messages.upsert':
            _logger.info("Ignored event type: %s", event_type)
            return request.make_response(json.dumps({'status': 'ignored', 'reason': 'not_upsert'}), headers=[('Content-Type', 'application/json')])
        
        payload_data = data.get('data', {})
        key = payload_data.get('key', {})
        message_data = payload_data.get('message', {})
        
        # Ignore fromMe
        if key.get('fromMe'):
            return request.make_response(json.dumps({'status': 'ignored', 'reason': 'from_me'}), headers=[('Content-Type', 'application/json')])
            
        remote_jid = key.get('remoteJid') 
        if not remote_jid:
            return request.make_response(json.dumps({'status': 'error', 'reason': 'no_jid'}), headers=[('Content-Type', 'application/json')])
            
        is_group = '@g.us' in remote_jid
        _logger.info("Processing message from: %s (Group: %s)", remote_jid, is_group)
        
        # Extract content
        text_body = ""
        media_content = None 
        
        media_type_map = {
            'imageMessage': 'image',
            'videoMessage': 'video',
            'documentMessage': 'document',
            'audioMessage': 'audio',
            'stickerMessage': 'image'
        }
        
        found_media_type = next((mt for mt in media_type_map if mt in message_data), None)
        
        if found_media_type:
            _logger.info("Found Media Type: %s", found_media_type)
            media_info = message_data[found_media_type]
            caption = media_info.get('caption', '')
            text_body = caption 
            
            # Fetch Base64 using FULL payload data (needs key and message)
            _logger.info("Fetching Base64 for %s", found_media_type)
            base64_data = request.env['whatsapp.evolution.api'].sudo().get_media_base64(payload_data)
            
            if base64_data:
                # Determine filename
                # Use a default filename WITHOUT extension first, to allow extension fixing logic to run
                default_name = f"whatsapp_{media_type_map[found_media_type]}"
                filename = media_info.get('fileName') or default_name
                
                # Force extension check if filename is the default one or has no extension
                if filename == default_name or '.' not in filename:
                    mime = media_info.get('mimetype', '')
                    if '/' in mime:
                        ext = mime.split('/')[-1].split(';')[0]
                        # Fix common mime extensions
                        if ext == 'plain': ext = 'txt'
                        if ext == 'quicktime': ext = 'mov'
                        filename = f"{filename}.{ext}"
                
                media_content = {
                    'name': filename,
                    'datas': base64_data, # This is base64 string
                    'type': 'binary',
                }
                _logger.info("Media Content Prepared: %s", media_content['name'])
            else:
                _logger.warning("FAILED: Base64 Data returned EMPTY/None")
        
        elif 'conversation' in message_data:
            text_body = message_data['conversation']
        elif 'extendedTextMessage' in message_data:
            text_body = message_data['extendedTextMessage'].get('text', '')
            
        if not text_body and not media_content:
             _logger.warning("No text or media content found.")
             return request.make_response(json.dumps({'status': 'ignored', 'reason': 'no_content'}), headers=[('Content-Type', 'application/json')])

        # 1. Start Partner Search Logic (The SENDER)
        Partner = request.env['res.partner'].sudo()
        
        if is_group:
            # For groups, sender is in 'participant'
            sender_jid = key.get('participant')
            if not sender_jid:
                _logger.warning("Group message without participant key")
                sender_jid = remote_jid # Fallback, unlikely
            clean_number = sender_jid.split('@')[0]
        else:
            clean_number = remote_jid.split('@')[0]
        
        # Defensive check for 'mobile' field
        domain = []
        if 'mobile' in Partner._fields:
            domain = ['|', ('mobile', '=', clean_number), ('phone', '=', clean_number)]
        else:
            domain = [('phone', '=', clean_number)]
            
        _logger.info("Searching Partner with domain: %s", domain)
        partner = Partner.search(domain, limit=1)
        
        if not partner:
            plus_number = '+' + clean_number
            if 'mobile' in Partner._fields:
                domain = ['|', ('mobile', '=', plus_number), ('phone', '=', plus_number)]
            else:
                domain = [('phone', '=', plus_number)]
            
            _logger.info("Retry Search Partner (with +) domain: %s", domain)
            partner = Partner.search(domain, limit=1)
            
        if partner:
             _logger.info("MATCHED Partner: %s (ID: %s) | Phone: %s | Mobile: %s", 
                          partner.name, partner.id, partner.phone, getattr(partner, 'mobile', 'N/A'))
            
        if not partner:
            if is_group:
                # User request: Do NOT create contacts for group members
                # Use a generic 'WhatsApp Group Guest'
                _logger.info("Unknown group member. Using generic Guest partner.")
                partner = Partner.search([('name', '=', 'WhatsApp Group Guest')], limit=1)
                if not partner:
                    partner = Partner.create({'name': 'WhatsApp Group Guest', 'active': True})
                
                # Prepend sender identity to body
                sender_name = payload_data.get('pushName') or f"+{clean_number}"
                if text_body:
                    text_body = f"*{sender_name}*: {text_body}"
                elif media_content:
                    # If it's just media, we can't easily prepend to body if it's strictly an attachment, 
                    # but we can set caption/body if it was empty.
                    text_body = f"*{sender_name}* sent an attachment"
            else:
                # Private chat: Create actual partner
                _logger.info("Creating new partner for %s", clean_number)
                
                # Try to get the user's display name from WhatsApp
                push_name = payload_data.get('pushName')
                partner_name = f"{push_name} (WhatsApp)" if push_name else f'+{clean_number}'
                
                vals = {
                    'name': partner_name,
                    'phone': '+' + clean_number
                }
                
                # Fetch Profile Picture
                try:
                    profile_pic = request.env['whatsapp.evolution.api'].sudo().fetch_profile_picture(remote_jid)
                    if profile_pic:
                        vals['image_1920'] = profile_pic
                except Exception as e:
                    _logger.warning("Failed to fetch profile picture: %s", str(e))

                if 'mobile' in Partner._fields:
                    vals['mobile'] = '+' + clean_number
                    
                partner = Partner.create(vals)
        else:
             _logger.info("Found existing partner: %s", partner.name)

        # 2. Find or Create Discuss Channel
        Channel = request.env['discuss.channel'].sudo()
        
        # Define Channel Identifier
        if is_group:
            # --- START GROUP APPROVAL LOGIC ---
            # Check if this group is known and accepted
            WhatsAppGroup = request.env['whatsapp.group'].sudo()
            wa_group = WhatsAppGroup.search([('whatsapp_id', '=', remote_jid)], limit=1)
            
            if not wa_group:
                # auto-create as pending
                _logger.info("New WhatsApp Group detected: %s. Creating pending record.", remote_jid)
                # Try to get subject from message data if available (rare in upsert w/o metadata)
                # Some events have 'pushName' but that's sender.
                # We'll default to JID or try to extract from conversation subject if present (unlikely here)
                group_name = f"WhatsApp Group ({remote_jid})"
                
                group_vals = {
                    'name': group_name,
                    'whatsapp_id': remote_jid,
                    'status': 'pending'
                }
                
                # Fetch Group Icon
                try:
                    group_pic = request.env['whatsapp.evolution.api'].sudo().fetch_profile_picture(remote_jid)
                    if group_pic:
                        group_vals['image_128'] = group_pic
                except Exception as e:
                    _logger.warning("Failed to fetch group icon: %s", str(e))
                
                WhatsAppGroup.create(group_vals)
                # STOP processing here
                return request.make_response(json.dumps({'status': 'pending_approval'}), headers=[('Content-Type', 'application/json')])
            
            if wa_group.status != 'accepted':
                _logger.info("Group %s is %s. Ignoring message.", remote_jid, wa_group.status)
                return request.make_response(json.dumps({'status': 'ignored', 'reason': 'group_not_accepted'}), headers=[('Content-Type', 'application/json')])
                
            # If accepted, continue...
            # Also update channel_name_prefix from the group name in our DB
            channel_name_prefix = wa_group.name
            channel_identifier = remote_jid
            # --- END GROUP APPROVAL LOGIC ---
            
            channel_identifier = remote_jid # Redundant assignment for clarity
        else:
            channel_identifier = clean_number # Use digits only for private
            channel_name_prefix = partner.name

        channel = Channel.search([
            ('whatsapp_number', '=', channel_identifier)
        ], limit=1)
        
        if not channel:
            _logger.info("Creating new WhatsApp channel for: %s", channel_identifier)
            
            # For groups, maybe try to be smarter with name if possible, otherwise generic
            # Private chat name logic uses Partner Name.
            # Group chat name: Odoo doesn't know the group subject from here easily without extra API call or parsing generic headers.
            # We'll use "WhatsApp Group [ID]" for now.
            name = f'{channel_name_prefix} ({channel_identifier})' if is_group else f'{partner.name} (WhatsApp)'
            
            # User Preference: ALL WhatsApp chats (Private or Group) are 'channel' type.
            # This makes them appear in "Channels" sidebar and allows >2 members (e.g. agents).
            c_type = 'channel'
             
            channel = Channel.create({
                'name': name,
                'channel_type': c_type,
                'whatsapp_number': channel_identifier,
                'channel_member_ids': [
                    (0, 0, {'partner_id': partner.id}),
                ]
            })
        else:
            # Ensure sender is in the channel (especially for groups)
            # Since we use 'channel' type now, we can safely add members (no 2-person limit).
            if partner.id not in channel.channel_member_ids.partner_id.ids:
                 _logger.info("Adding partner %s to existing channel", partner.name)
                 channel.write({
                    'channel_member_ids': [(0, 0, {'partner_id': partner.id})]
                })

        # 3. Post Message with Attachments
        post_values = {
            'body': text_body,
            'author_id': partner.id,
            'message_type': 'comment',
            'subtype_xmlid': 'mail.mt_comment',
        }
        
        # Prepare attachments list for message_post
        attachments_list = []
        if media_content:
            try:
                # Odoo message_post expects raw bytes for content if not using attachment_ids
                file_content = base64.b64decode(media_content['datas'])
                attachments_list.append((media_content['name'], file_content))
                _logger.info("Attachment prepared for message_post: %s", media_content['name'])
            except Exception as e:
                _logger.error("Failed to decode base64 for attachment: %s", str(e))

        if attachments_list:
            post_values['attachments'] = attachments_list

        _logger.info("Posting message... Attachments count: %d", len(attachments_list))
        channel.message_post(**post_values)
        
        return request.make_response(json.dumps({'status': 'success'}), headers=[('Content-Type', 'application/json')])
