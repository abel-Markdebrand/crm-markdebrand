# -*- coding: utf-8 -*-
from odoo import models, fields, api

class WhatsappIntegration(models.Model):
    """
    WhatsApp Integration Model for Odoo 19.
    """
    _name = 'whatsapp.integration'
    _description = 'WhatsApp Integration Model'

    name = fields.Char(string="Name", required=True, help="Name of the record")
    description = fields.Text(string="Description")
    active = fields.Boolean(default=True)
    
    # Updated conventions for Odoo 19
    # Example of a monetary field with currency
    currency_id = fields.Many2one('res.currency', string='Currency')
    amount = fields.Monetary(string='Amount', currency_field='currency_id')

    @api.model
    def _get_default_name(self):
        return "New Record"
