# -*- coding: utf-8 -*-
from odoo import models, fields

class CrmLead(models.Model):
    _inherit = 'crm.lead'

    def action_whatsapp_chat(self):
        """Open WhatsApp chat for this lead."""
        self.ensure_one()
        # Prioritize existing partner, then mobile, then phone
        partner_id = self.partner_id.id if self.partner_id else None
        
        phone = self.phone
             
        name = self.contact_name or self.name
        
        return self.env['discuss.channel'].open_whatsapp_chat(partner_id=partner_id, phone=phone, name=name)
