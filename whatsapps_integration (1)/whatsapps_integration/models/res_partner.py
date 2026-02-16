# -*- coding: utf-8 -*-
from odoo import models, fields

class ResPartner(models.Model):
    _inherit = 'res.partner'

    def action_whatsapp_chat(self):
        """Open WhatsApp chat for this partner."""
        self.ensure_one()
        return self.env['discuss.channel'].open_whatsapp_chat(partner_id=self.id)
