{
    'name': 'Website Sale Automation (SO -> Invoice -> Post)',
    'version': '1.0',
    'category': 'Website/Website',
    'summary': 'Automate Sale Order confirmation and Invoicing for E-commerce',
    'description': """
        This module modifies the website sale flow:
        1. Automatically confirms the Sale Order (Quotation -> Sale Order).
        2. Automatically creates the Invoice.
        3. Automatically posts the Invoice.
        Note: Ensure Product Invoicing Policy is set to 'Ordered Quantities'.
    """,
    'author': 'Antigravity / Senior Odoo Developer',
    'depends': ['sale', 'website_sale', 'account'],
    'data': [],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
}
