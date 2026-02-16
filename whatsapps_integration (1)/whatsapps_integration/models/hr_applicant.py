# -*- coding: utf-8 -*-
from odoo import models, fields

class HrApplicant(models.Model):
    _inherit = 'hr.applicant'

    def action_whatsapp_chat(self):
        """Open WhatsApp chat for this applicant."""
        self.ensure_one()
        partner_id = self.partner_id.id if self.partner_id else None
        phone = self.partner_mobile or self.partner_phone
        name = self.partner_name or self.name
        
        return self.env['discuss.channel'].open_whatsapp_chat(partner_id=partner_id, phone=phone, name=name)
