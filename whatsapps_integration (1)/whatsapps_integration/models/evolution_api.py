# -*- coding: utf-8 -*-
import requests
import json
import logging
from odoo import models, api, _
from odoo.exceptions import UserError

_logger = logging.getLogger(__name__)

class EvolutionApi(models.AbstractModel):
    _name = 'whatsapp.evolution.api'
    _description = 'Evolution API Service'

    @api.model
    def _get_api_config(self):
        """Retrieve API configuration from settings."""
        params = self.env['ir.config_parameter'].sudo()
        url = params.get_param('whatsapp.evolution_api_url')
        token = params.get_param('whatsapp.evolution_api_token')
        instance = params.get_param('whatsapp.evolution_instance_name') or 'Odoo'
        
        if not url or not token:
             # Option to log warning but not crash if used loosely, but better to enforce for sending
             return None, None, None
        
        # Ensure URL doesn't end with slash to avoid double slashes
        return url.rstrip('/'), token, instance

    @api.model
    def send_message(self, phone, message):
        """Send a text message via Evolution API."""
        base_url, token, instance = self._get_api_config()
        if not base_url:
            raise UserError(_("Evolution API is not configured. Please check settings."))

        headers = {
            'Content-Type': 'application/json',
            'apikey': token
        }
        
        endpoint = f"{base_url}/message/sendText/{instance}"
        
        # Determine if it's a group or private number
        if '@g.us' in phone:
            clean_phone = phone # Use as-is for groups
        else:
            # Ensure only digits are sent for private numbers
            import re
            clean_phone = re.sub(r'\D', '', phone)
        
        # Evolution API v2.3.7 often accepts 'text' at root or 'textMessage'
        # Simplified payload to avoid schema validation errors with 'options'
        payload = {
            "number": clean_phone,
            "text": message,
            "delay": 1200,
            "linkPreview": False
        }
        
        # If the above 400s, it might need "textMessage": {"text": message} WITHOUT options
        # But let's try this standard format first which works on many v2 instances.

        try:
            response = requests.post(endpoint, headers=headers, json=payload, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            # Fallback for "textMessage" object requirement if 400
            if isinstance(e, requests.exceptions.HTTPError) and e.response.status_code == 400:
                try:
                    _logger.warning("First attempt 400, retrying with textMessage object...")
                    payload_v2 = {
                        "number": clean_phone,
                        "textMessage": {"text": message},
                        "options": {"delay": 1200, "presence": "composing"}
                    }
                    response = requests.post(endpoint, headers=headers, json=payload_v2, timeout=10)
                    response.raise_for_status()
                    return response.json()
                except Exception as e2:
                    _logger.error("Retry failed: %s", str(e2))
            
            _logger.error("Failed to send WhatsApp message to %s: %s", phone, str(e))
            return {'error': str(e)}

    @api.model
    def send_media(self, phone, media_type, media_base64, caption=None, file_name=None, mimetype=None):
        """
        Send a media message via Evolution API.
        :param phone: Recipient number
        :param media_type: 'image', 'video', 'document', 'audio'
        :param media_base64: Base64 string of the file
        :param caption: Text caption (optional)
        :param file_name: Name of the file (important for documents)
        :param mimetype: Mime type of the file (e.g. image/jpeg)
        """
        base_url, token, instance = self._get_api_config()
        if not base_url:
             raise UserError(_("Evolution API is not configured."))

        headers = {
            'Content-Type': 'application/json',
            'apikey': token
        }
        
        endpoint = f"{base_url}/message/sendMedia/{instance}"
        
        # Determine if it's a group or private number
        if '@g.us' in phone:
            clean_phone = phone # Use as-is for groups
        else:
            # Ensure only digits are sent for private numbers
            import re
            clean_phone = re.sub(r'\D', '', phone)
        
        if ',' in media_base64:
             header, base64_data = media_base64.split(',', 1)
             media_base64 = base64_data # Raw for v2 flat structure
        
        # Evolution API v2.3.7 PROVEN working payload: 
        # Flat structure with RAW base64 (no data header)
        payload = {
            "number": clean_phone,
            "mediatype": media_type,
            "mimetype": mimetype or "",
            "caption": caption or "",
            "media": media_base64,
            "fileName": file_name
        }
        
        try:
            response = requests.post(endpoint, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            _logger.error("Failed to send WhatsApp media to %s: %s", phone, str(e))
            return {'error': str(e)}
            
    @api.model
    def get_media_base64(self, message_object):
        """
        Retrieve Base64 content from a media message using Evolution API.
        :param message_object: The full message dict from the webhook
        """
        base_url, token, instance = self._get_api_config()
        if not base_url:
            return None

        headers = {
            'Content-Type': 'application/json',
            'apikey': token
        }
        
        endpoint = f"{base_url}/chat/getBase64FromMediaMessage/{instance}"
        
        payload = {
            "message": message_object,
            "convertToMp4": False # optional, but good for audio/stickers sometimes
        }

        try:
            _logger.info("Fetching media from: %s", endpoint)
            response = requests.post(endpoint, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            _logger.info("Media Fetch Response Keys: %s", list(data.keys()))
            if 'base64' in data:
                 _logger.info("Found key 'base64' (sample: %s...)", str(data['base64'])[:50])
            elif 'data' in data:
                 _logger.info("Found key 'data' (sample: %s...)", str(data['data'])[:50])
            
            # Evolution API v2 might return { "base64": "..." } or { "data": "..." }
            base64_val = data.get('base64') or data.get('data')
            
            if not base64_val:
                _logger.warning("No 'base64' or 'data' key in response: %s", data.keys())
                
            return base64_val
        except requests.exceptions.RequestException as e:
            _logger.error("Failed to retrieve media base64: %s", str(e))
            if hasattr(e, 'response') and e.response:
                 _logger.error("Response Content: %s", e.response.text)
            return None

    @api.model
    def test_connection(self):
        """
        Test connection to Evolution API instance.
        """
        base_url, token, instance = self._get_api_config()
        if not base_url or not token:
            return {'success': False, 'message': 'Missing URL or Token in settings.'}

        headers = {
            'Content-Type': 'application/json',
            'apikey': token
        }
        
        # Endpoint to check connection state of the specific instance
        endpoint = f"{base_url}/instance/connectionState/{instance}"
        
        try:
            response = requests.get(endpoint, headers=headers, timeout=5)
            if response.status_code == 200:
                data = response.json()
                # Evolution v2 usually returns { "instance": { "state": "open" } } or just state object
                state = data.get('instance', {}).get('state') or data.get('state') or 'unknown'
                return {'success': True, 'message': f'Connection Successful! Instance State: {state}'}
            elif response.status_code == 404:
                return {'success': False, 'message': f'Instance "{instance}" not found (404).'}
            elif response.status_code == 401:
                return {'success': False, 'message': 'Authentication failed (401). Check API Token.'}
            else:
                return {'success': False, 'message': f'Error {response.status_code}: {response.text}'}
        except requests.exceptions.RequestException as e:
            return {'success': False, 'message': f'Connection Failed: {str(e)}'}

    @api.model
    def fetch_all_groups(self):
        """
        Fetch all groups from the connected Evolution API instance.
        Returns a list of dicts: [{'id': '...', 'subject': '...'}, ...]
        """
        base_url, token, instance = self._get_api_config()
        if not base_url or not token:
            return []

        headers = {
            'Content-Type': 'application/json',
            'apikey': token
        }
        
        endpoint = f"{base_url}/group/fetchAllGroups/{instance}?getParticipants=false"
        
        try:
            response = requests.get(endpoint, headers=headers, timeout=15)
            if response.status_code == 200:
                data = response.json()
                # Evolution v2 returns usually a list of group objects, or { "groups": [...] }
                # Let's handle both just in case
                groups_data = data if isinstance(data, list) else data.get('groups', [])
                
                result = []
                for g in groups_data:
                    jid = g.get('id')
                    subject = g.get('subject') or g.get('name') or 'Unknown Group'
                    if jid:
                        result.append({'id': jid, 'subject': subject})
                return result
            else:
                _logger.error("Failed to fetch groups: %d %s", response.status_code, response.text)
                return []
        except requests.exceptions.RequestException as e:
            _logger.error("Error fetching groups: %s", str(e))
            return []

    @api.model
    def fetch_profile_picture(self, jid):
        """
        Fetch profile picture URL and download it as Base64.
        Returns: base64 string or None
        """
        base_url, token, instance = self._get_api_config()
        if not base_url or not token:
            return None

        headers = {
            'Content-Type': 'application/json',
            'apikey': token
        }
        
        # Endpoint to fetch URL
        endpoint = f"{base_url}/chat/fetchProfilePictureUrl/{instance}"
        payload = {"number": jid}
        
        try:
            _logger.info("Fetching profile picture for JID: %s", jid)
            response = requests.post(endpoint, headers=headers, json=payload, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                _logger.info("Profile Picture Response: %s", data)
                # Evolution v2 structure: { "profilePictureUrl": "https://..." }
                url = data.get('profilePictureUrl') or data.get('picture')
                
                if url:
                    _logger.info("Downloading image from: %s", url)
                    image_response = requests.get(url, timeout=10)
                    if image_response.status_code == 200:
                        import base64
                        return base64.b64encode(image_response.content).decode('utf-8')
                    else:
                        _logger.error("Failed to download image from URL: %d", image_response.status_code)
                else:
                    _logger.warning("No 'profilePictureUrl' in response.")
            else:
                 _logger.error("Fetch Profile Picture API Error: %d %s", response.status_code, response.text)
            return None
        except Exception as e:
            _logger.error("Error fetching profile picture for %s: %s", jid, str(e))
            return None

