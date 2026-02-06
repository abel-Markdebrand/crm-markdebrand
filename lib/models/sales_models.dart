import '../utils/odoo_utils.dart';

class Product {
  final int id;
  final String name;
  final double listPrice;

  Product({required this.id, required this.name, required this.listPrice});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: OdooUtils.safeString(json['name']) == ''
          ? 'Product'
          : OdooUtils.safeString(json['name']),
      listPrice: (json['list_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderLine {
  final int id;
  final int productId;
  final String productName;
  final double productUomQty;
  final double priceUnit;
  final double priceSubtotal;

  OrderLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productUomQty,
    required this.priceUnit,
    required this.priceSubtotal,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    // Parseo seguro de product_id
    int pId = 0;
    String pName = 'Unknown';
    if (json['product_id'] is List && (json['product_id'] as List).isNotEmpty) {
      pId = json['product_id'][0];
      pName = OdooUtils.safeString(json['product_id'][1]);
    }

    return OrderLine(
      id: json['id'] as int,
      productId: pId,
      productName: pName,
      productUomQty: (json['product_uom_qty'] as num?)?.toDouble() ?? 0.0,
      priceUnit: (json['price_unit'] as num?)?.toDouble() ?? 0.0,
      priceSubtotal: (json['price_subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SaleOrder {
  final int id;
  final String name;
  final int partnerId;
  final String partnerName;
  final double amountTotal;
  final String state;
  final List<int>
  orderLineIds; // IDs de las líneas para fetching separado si fuera necesario
  final String? dateOrder;

  SaleOrder({
    required this.id,
    required this.name,
    required this.partnerId,
    required this.partnerName,
    required this.amountTotal,
    required this.state,
    required this.orderLineIds,
    this.dateOrder,
  });

  factory SaleOrder.fromJson(Map<String, dynamic> json) {
    int pId = 0;
    String pName = 'Unknown';
    if (json['partner_id'] is List && (json['partner_id'] as List).isNotEmpty) {
      pId = json['partner_id'][0];
      pName = OdooUtils.safeString(json['partner_id'][1]);
    } else if (json['partner_id'] is int) {
      pId = json['partner_id'];
    }

    return SaleOrder(
      id: json['id'] as int,
      name: OdooUtils.safeString(json['name']) == ''
          ? 'Order'
          : OdooUtils.safeString(json['name']),
      partnerId: pId,
      partnerName: pName,
      amountTotal: (json['amount_total'] as num?)?.toDouble() ?? 0.0,
      state: OdooUtils.safeString(json['state']) == ''
          ? 'draft'
          : OdooUtils.safeString(json['state']),
      orderLineIds: json['order_line'] is List
          ? (json['order_line'] as List).cast<int>()
          : [],
      dateOrder: OdooUtils.safeString(json['date_order']),
    );
  }
}
