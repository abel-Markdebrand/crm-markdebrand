# -*- coding: utf-8 -*-
from odoo import http
from odoo.http import request

class WhatsappIntegrationController(http.Controller):
    
    @http.route('/whatsapp_integration/hello', auth='public', type='http', website=True)
    def hello(self, **kw):
        return "Hello, WhatsApp Integration World!"

    @http.route('/whatsapp_integration/objects', auth='user', type='json')
    def list_objects(self, **kw):
        objects = request.env['whatsapp.integration'].search([])
        return objects.read(['name', 'description'])
