class ProductDetails {
  final String id;
  final String price;
  const ProductDetails({required this.id, this.price = ''});
}

enum PurchaseStatus { pending, purchased, error, restored, canceled }

class PurchaseDetails {
  String productID = '';
  PurchaseStatus status = PurchaseStatus.canceled;
  bool pendingCompletePurchase = false;
}

class PurchaseParam {
  final ProductDetails productDetails;
  PurchaseParam({required this.productDetails});
}

class ProductDetailsResponse {
  final List<ProductDetails> productDetails = const [];
}

class InAppPurchase {
  static final InAppPurchase instance = InAppPurchase._();
  InAppPurchase._();
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  Future<bool> isAvailable() async => false;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse();
  Future<void> restorePurchases() async {}
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      false;
  Future<void> completePurchase(PurchaseDetails p) async {}
}
