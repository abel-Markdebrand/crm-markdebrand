# -*- coding: utf-8 -*-
from odoo import models, fields, api

class WhatsAppGroup(models.Model):
    _name = 'whatsapp.group'
    _description = 'WhatsApp Group'
    _inherit = ['mail.thread', 'mail.activity.mixin']

    name = fields.Char(string="Group Name", required=True)
    whatsapp_id = fields.Char(string="Group JID", required=True, help="The WhatsApp Group ID (e.g. 12345@g.us)")
    active_channel_id = fields.Many2one('discuss.channel', string="Linked Channel", readonly=True)
    image_128 = fields.Image("Logo", max_width=128, max_height=128)
    
    status = fields.Selection([
        ('pending', 'Pending Approval'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected')
    ], string="Status", default='pending', tracking=True, required=True)

    _sql_constraints = [
        ('whatsapp_id_unique', 'unique(whatsapp_id)', 'This WhatsApp Group already exists in the system.')
    ]

    @api.model
    def action_fetch_groups(self):
        """Fetch groups from API and create pending records for new ones."""
        groups = self.env['whatsapp.evolution.api'].fetch_all_groups()
        created_count = 0
        
        for g in groups:
            jid = g.get('id')
            subject = g.get('subject')
            
            # Check if exists
            existing = self.search([('whatsapp_id', '=', jid)], limit=1)
            target_record = False
            
            if not existing:
                target_record = self.create({
                    'name': subject,
                    'whatsapp_id': jid,
                    'status': 'pending'
                })
                created_count += 1
            else:
                target_record = existing
                # Update name if it is generic or different
                if existing.name != subject and subject != 'Unknown Group':
                     existing.write({'name': subject})
            
            # Auto-fetch image if missing
            if target_record and not target_record.image_128:
                try:
                    pic = self.env['whatsapp.evolution.api'].fetch_profile_picture(jid)
                    if pic:
                        target_record.image_128 = pic
                except Exception:
                    pass
                
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Group Sync',
                'message': f'Sync Complete. Found {len(groups)} groups. Created {created_count} new pending groups.',
                'type': 'success',
                'sticky': False,
            }
        }

    def action_fetch_image(self):
        """Fetch the group profile picture from WhatsApp."""
        for record in self:
            if not record.whatsapp_id:
                continue
            try:
                pic = self.env['whatsapp.evolution.api'].fetch_profile_picture(record.whatsapp_id)
                if pic:
                    record.image_128 = pic
            except Exception as e:
                # Log but don't crash
                 pass
        return True

    def action_approve(self):
        """Approve the group and optionally pre-create the channel."""
        self.ensure_one()
        self.status = 'accepted'
        
        # Determine image (fetch if missing)
        if not self.image_128:
            self.action_fetch_image()

        # Optionally create the channel immediately if it doesn't exist
        if not self.active_channel_id:
            Channel = self.env['discuss.channel']
            existing = Channel.search([('channel_type', '=', 'whatsapp'), ('whatsapp_number', '=', self.whatsapp_id)], limit=1)
            if existing:
                self.active_channel_id = existing
                # Update existing channel image too if missing
                if not existing.avatar_128 and self.image_128:
                     existing.write({'avatar_128': self.image_128})
            else:
                new_channel = Channel.create({
                    'name': self.name,
                    'channel_type': 'channel',
                    'whatsapp_number': self.whatsapp_id,
                    'avatar_128': self.image_128 # Use avatar_128 for discuss.channel usually
                })
                self.active_channel_id = new_channel
                
    def action_reject(self):
        """Reject the group (ignore messages)."""
        for record in self:
            record.status = 'rejected'
