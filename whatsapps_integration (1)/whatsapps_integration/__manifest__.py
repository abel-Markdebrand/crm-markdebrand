{
    'name': 'WhatsApp Integration',
    'version': '19.0.1.0.0',
    'summary': 'WhatsApp Integration for Odoo 19',
    'category': 'Tools',
    'author': 'Engelbert Rodriguez',
    'website': 'https://www.markdebrand.com',
    'license': 'LGPL-3',
    'depends': ['base', 'crm', 'hr_recruitment'],
    'data': [
        'security/security.xml',
        'security/ir.model.access.csv',
        'views/base_view.xml',
        'views/res_config_settings_views.xml',
        'views/res_partner_views.xml',
        'views/crm_lead_views.xml',
        'views/hr_recruitment_views.xml',
        'views/whatsapp_group_views.xml',
        'data/user_assignment.xml',
    ],
    'demo': [],
    'installable': True,
    'application': True,
    'auto_install': False,
    'description': """
WhatsApp Integration Module
===========================
This module provides integration with WhatsApp for Odoo 19.
""",
}
