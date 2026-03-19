from odoo import models, api, _
import logging

_logger = logging.getLogger(__name__)

class SaleOrder(models.Model):
    _inherit = 'sale.order'

    def action_confirm(self):
        """
        Extiende action_confirm para automatizar la facturación en pedidos de e-commerce.
        """
        res = super(SaleOrder, self).action_confirm()
        
        for order in self:
            # Activamos si es e-commerce O si detectamos que viene de la App Móvil
            # (Podemos detectar el origen por el contexto o por un campo específico)
            is_mobile = self.env.context.get('is_mobile_order') or (order.client_order_ref and 'MOB-' in order.client_order_ref)
            
            if order.website_id or is_mobile:
                # 1. Crear la factura
                # El método _create_invoices() maneja la creación masiva o individual
                # Basado en la política de facturación del producto (debe ser 'Ordered Quantities')
                try:
                    invoices = order._create_invoices()
                    if invoices:
                        # 2. Publicar/Asentar la factura automáticamente
                        invoices.action_post()
                        _logger.info("Factura automática creada y publicada para SO %s", order.name)
                    else:
                        _logger.warning("No se pudo crear factura automática para SO %s. Verifique la política de facturación de los productos.", order.name)
                except Exception as e:
                    _logger.error("Error al automatizar factura para SO %s: %s", order.name, str(e))
        
        return res
