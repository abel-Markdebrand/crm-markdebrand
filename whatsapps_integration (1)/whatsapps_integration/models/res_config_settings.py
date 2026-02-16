# -*- coding: utf-8 -*-
from odoo import fields, models

class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    evolution_api_url = fields.Char(string='Evolution API URL', config_parameter='whatsapp.evolution_api_url', help="Base URL of your Evolution API instance")
    evolution_api_token = fields.Char(string='Global API Token', config_parameter='whatsapp.evolution_api_token', help="Global API Key for authentication")
    evolution_instance_name = fields.Char(string='Instance Name', config_parameter='whatsapp.evolution_instance_name', default='Odoo', help="Name of the instance to connect to")

    def action_test_connection(self):
        """Test the API connection and show notification."""
        # Force save settings first so we test what's typed? 
        # Actually standard settings flow saves when you click save, but button action might run before.
        # It's better to use values from self if possible, or warn user to save first.
        # But config_parameters are used in `_get_api_config`.
        # So we should suggest saving first, or transient values.
        # However, for simplicity, we assume user saved or we explicitly set params from current view values (hacky in settings).
        # Let's rely on saved values for now, or self.env['ir.config_parameter'] which is what `test_connection` uses.
        
        # If the user just typed and hasn't saved, this test will use OLD values. 
        # To fix this in settings context, we can manually set the params temporarily or pass them.
        # But `evolution_api` model reads from config_parameter.
        
        # We will set the parameters from the current record (self) before testing.
        self.set_values()
        
        result = self.env['whatsapp.evolution.api'].test_connection()
        
        type_notif = 'success' if result['success'] else 'danger'
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Connection Test',
                'message': result['message'],
                'type': type_notif,
                'sticky': False,
            }
        }
