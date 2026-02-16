# -*- coding: utf-8 -*-
from odoo import models, fields, api

class DiscussChannel(models.Model):
    _inherit = 'discuss.channel'

    channel_type = fields.Selection(selection_add=[('whatsapp', 'WhatsApp Conversation')], ondelete={'whatsapp': 'cascade'})
    whatsapp_number = fields.Char(string="WhatsApp Number")

    def message_post(self, **kwargs):
        """Override to intercept messages sent to WhatsApp channels."""
        message = super(DiscussChannel, self).message_post(**kwargs)
        
        # Check if this is a WhatsApp channel (has number) and the message is not coming from the system/webhook
        # (avoid infinite loops if we post back received messages)
        # Note: 'message_type' often 'comment' for user messages.
        if self.whatsapp_number and kwargs.get('message_type') != 'notification':
             # We assume if it's a comment from a user, we send it.
             # Need to handle case where the message is an 'incoming' one we just created.
             # Typically, incoming messages will have an author that matches the partner.
             # Outgoing messages have author = current user.
             
             # A simple heuristic: if the author is the current user (agent), send it.
             current_author = self.env.user.partner_id
             msg_author = message.author_id
             
             if msg_author == current_author:
                 # 2. Handle Text Body (initial capture)
                 body_text = message.body or ''
                 import re
                 clean_text = re.sub('<[^<]+?>', '', body_text).strip()
                 
                 # Check if body is just the default Odoo "Sent attachment" message
                 # If so, we might not want to use it even as a caption, or maybe we do?
                 # Usually users prefer no caption if they didn't type anything.
                 # Odoo default: "Sent attachment: file.png"
                 # Let's use it as caption if provided, but NOT send as separate text.
                 
                 caption_to_use = clean_text
                 
                 # 1. Handle Attachments
                 if message.attachment_ids:
                     for i, attachment in enumerate(message.attachment_ids):
                         media_type = 'document' # default
                         mime = attachment.mimetype
                         if 'image' in mime:
                             media_type = 'image'
                         elif 'video' in mime:
                             media_type = 'video'
                         elif 'audio' in mime:
                             media_type = 'audio'
                         
                         media_base64 = attachment.datas.decode('utf-8') if attachment.datas else ''
                         
                         # Use body as caption for the FIRST attachment only, and only if it exists
                         # If there are multiple attachments, only the first gets the caption (standard behavior)
                         # OR we could repeat it, but that's annoying.
                         caption = caption_to_use if i == 0 else ''
                         
                         self.env['whatsapp.evolution.api'].send_media(
                            phone=self.whatsapp_number,
                            media_type=media_type,
                            media_base64=media_base64,
                            caption=caption,
                            file_name=attachment.name,
                            mimetype=mime
                         )
                     
                     # If we sent attachments, we assume the body was consumed as caption (or was just "Sent attachment")
                     # So we clear it to prevent sending a duplicate text message
                     clean_text = ''
                 
                 # 3. Handle Text Body (if NO attachments or if we want to support text+media separately)
                 # In this logic, if attachments exist, we consumed the text as caption.
                 # This prevents the "Sent attachment: ..." separate message.
                 if clean_text:
                     self.env['whatsapp.evolution.api'].send_message(self.whatsapp_number, clean_text)
        
        return message

    @api.model
    def open_whatsapp_chat(self, partner_id=None, phone=None, name=None):
        """
        Helper to open or create a WhatsApp channel and return the action.
        Prioritizes partner_id if provided.
        """
    @api.model
    def open_whatsapp_chat(self, partner_id=None, phone=None, name=None):
        """
        Helper to open or create a WhatsApp channel and return the action.
        Prioritizes partner_id if provided.
        """
        Partner = self.env['res.partner']
        partner = None

        if partner_id:
            partner = Partner.browse(partner_id)
        elif phone:
            # Clean phone
            phone = phone.replace(' ', '').replace('-', '').replace('(', '').replace(')', '')
            # Search partner by mobile
            partner = Partner.search(['|', ('mobile', '=', phone), ('phone', '=', phone)], limit=1)
            if not partner and name:
                partner = Partner.create({
                    'name': name,
                    'mobile': phone
                })
        
        if not partner:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Error',
                    'message': 'No valid partner or phone number found to start WhatsApp chat.',
                    'type': 'danger',
                    'sticky': False,
                }
            }
            
        # Ensure partner has mobile for the channel
        mobile = False
        if hasattr(partner, 'mobile'):
            mobile = partner.mobile
            
        if not mobile:
             mobile = partner.phone
             
        if not mobile:
             return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Error',
                    'message': 'Partner has no mobile number.',
                    'type': 'danger',
                    'sticky': False,
                }
            }
            
        # Normalize mobile for channel identifier (simple version)
        # Use simple regex or filter to keep only digits
        import re
        target_number = re.sub(r'\D', '', mobile)
        
        # Find existing channel
        channel = self.search([
            ('whatsapp_number', '=', target_number)
        ], limit=1)
        
        if not channel:
            channel = self.create({
                'name': f'{partner.name} (WhatsApp)',
                'channel_type': 'channel',
                'whatsapp_number': target_number,
                'channel_member_ids': [
                    (0, 0, {'partner_id': partner.id}),
                    (0, 0, {'partner_id': self.env.user.partner_id.id}),
                ]
            })
        else:
            # Ensure current user is a member
            if self.env.user.partner_id not in channel.channel_member_ids.partner_id:
                channel.write({
                    'channel_member_ids': [(0, 0, {'partner_id': self.env.user.partner_id.id})]
                })

        return {
            'type': 'ir.actions.client',
            'tag': 'mail.action_discuss',
            'params': {
                'active_id': channel.id,
            },
            'context': {
                'active_id': channel.id,
                'is_discussion': True, # Hint for discuss app
            }
        }
