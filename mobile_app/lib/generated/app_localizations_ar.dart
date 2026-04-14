// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get add => 'إضافة';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get close => 'إغلاق';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get warehouse => 'المستودع';

  @override
  String get warehouseDashboard => 'لوحة تحكم المستودع';

  @override
  String get adminDashboard => 'لوحة تحكم المسؤول';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get stock => 'المخزون';

  @override
  String get warehouseStockEntryBannerTitle => 'إضافة مخزون من المستودع';

  @override
  String warehouseStockEntryLine(
      String productName, String quantity, String storeName) {
    return '$productName · +$quantity · $storeName';
  }

  @override
  String warehouseStockAddedOnCard(String quantity) {
    return '+$quantity (مستودع)';
  }

  @override
  String get projects => 'المشاريع';

  @override
  String get orders => 'الطلبات';

  @override
  String get myDistributions => 'توزيعاتي';

  @override
  String get totalStock => 'إجمالي المخزون';

  @override
  String get reports => 'التقارير';

  @override
  String get selectReportType => 'اختر نوع التقرير';

  @override
  String get searchReportsHint => 'بحث التقارير...';

  @override
  String get noReportTypesMatchSearch => 'لا يوجد نوع تقرير يطابق البحث.';

  @override
  String get searchReportHint => 'بحث في التقرير...';

  @override
  String get reportValidatedDistributions => 'التوزيعات المصدّقة';

  @override
  String get reportValidatedDistributionsMenu => 'توزيعات\nمصدّقة';

  @override
  String get reportApprovedReturns => 'المرتجعات المعتمدة';

  @override
  String get reportApprovedReturnsMenu => 'مرتجعات\nمعتمدة';

  @override
  String get reportStockHistory => 'سجل المخزون';

  @override
  String get reportStockHistoryMenu => 'سجل\nالمخزون';

  @override
  String get reportProjects => 'المشاريع';

  @override
  String get reportProjectsMenu => 'المشاريع';

  @override
  String get reportExportProjectPdf => 'تصدير PDF';

  @override
  String get projectSavedShort => 'تم حفظ المشروع';

  @override
  String get quantityRest => 'الباقي';

  @override
  String get reportDeleteTypeDistribution => 'التوزيع';

  @override
  String get reportDeleteTypeOrder => 'الطلب';

  @override
  String get reportDeleteTypeReturn => 'الإرجاع';

  @override
  String get reportDeleteTypeDamagedProduct => 'سجل المنتج التالف';

  @override
  String get reportDeleteTypeStockEntry => 'سجل المخزون';

  @override
  String get damagedProducts => 'المنتجات التالفة';

  @override
  String get damagedProductsMenu => 'المنتجات\nالتالفة';

  @override
  String get returns => 'المرتجعات';

  @override
  String get damages => 'الأضرار';

  @override
  String get users => 'المستخدمون';

  @override
  String get stores => 'المتاجر';

  @override
  String get products => 'المنتجات';

  @override
  String get distributions => 'التوزيعات';

  @override
  String get supplementaryRequests => 'طلبات إضافية';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get signInToContinue => 'تسجيل الدخول للمتابعة';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get pleaseEnterEmail => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get pleaseEnterValidEmail => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String get pleaseEnterPassword => 'يرجى إدخال كلمة المرور';

  @override
  String get createDistribution => 'إنشاء توزيع';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get product => 'المنتج';

  @override
  String get quantity => 'الكمية';

  @override
  String get project => 'المشروع';

  @override
  String get store => 'المتجر';

  @override
  String get depot => 'المستودع';

  @override
  String get sourceStoreDepot => 'المصدر (متجر/مستودع)';

  @override
  String get selectLocationHint => 'اختر الموقع الذي يحتوي على المخزون للتوزيع';

  @override
  String get materialRequestOptional => 'طلب مواد (اختياري)';

  @override
  String get materialRequestHint => 'اتركه فارغاً للإنشاء التلقائي';

  @override
  String get distributionDate => 'تاريخ التوزيع';

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get selectProjectFirst => 'حدد مشروعاً أولاً.';

  @override
  String get noProductsRequested =>
      'لا توجد منتجات مطلوبة من المستخدمين لهذا المشروع.';

  @override
  String get pleaseSelectProjectStore =>
      'يرجى اختيار المشروع والمتجر وإضافة منتج واحد على الأقل.';

  @override
  String distributionCreated(String mr) {
    return 'تم إنشاء التوزيع. طلب المواد: $mr';
  }

  @override
  String get noProductsAdded =>
      'لم تتم إضافة منتجات. اضغط إضافة لإضافة المنتجات.';

  @override
  String get selectProjectFirstShort => 'حدد المشروع أولاً';

  @override
  String get noProductsRequestedShort => 'لا توجد منتجات مطلوبة';

  @override
  String get pleaseEnterQuantity => 'يرجى إدخال كمية أكبر من 0';

  @override
  String get deleteDistribution => 'حذف التوزيع';

  @override
  String get refuseDistribution => 'رفض التوزيع';

  @override
  String get validateDistribution => 'التحقق من التوزيع';

  @override
  String get approve => 'موافقة';

  @override
  String get validate => 'تحقق';

  @override
  String get refuse => 'رفض';

  @override
  String get search => 'بحث';

  @override
  String searchHint(String what) {
    return 'بحث $what...';
  }

  @override
  String get searchUsersHint => 'بحث المستخدمين...';

  @override
  String get searchProductsHint => 'بحث المنتجات...';

  @override
  String get searchOrdersHint => 'بحث الطلبات...';

  @override
  String get searchProjectsHint => 'بحث المشاريع...';

  @override
  String get searchStoresHint => 'بحث المتاجر...';

  @override
  String get searchDistributionsHint => 'بحث التوزيعات...';

  @override
  String get noDistributionsMatch => 'لا تتطابق التوزيعات مع البحث.';

  @override
  String get noDistributionsCreateHint =>
      'لا توجد توزيعات بعد. أنشئ التوزيعات عبر الواجهة أو أضف نموذجاً.';

  @override
  String get notifications => 'الإشعارات';

  @override
  String distributionAccepted(String bon) {
    return 'تم قبول التوزيع. طلب المواد: $bon';
  }

  @override
  String distributionRefused(String bon) {
    return 'تم رفض التوزيع. طلب المواد: $bon';
  }

  @override
  String get noDistributions => 'لا توجد توزيعات بعد.';

  @override
  String get noOrders => 'لا توجد طلبات بعد.';

  @override
  String get noOrdersYetUser => 'لا توجد طلبات بعد.\nستظهر طلباتك هنا.';

  @override
  String noResultsFor(String query) {
    return 'لا توجد نتائج لـ \"$query\"';
  }

  @override
  String get noProjects => 'لا توجد مشاريع بعد.';

  @override
  String get noStores => 'لا توجد متاجر بعد.';

  @override
  String get noStoresMatch => 'لا تتطابق المتاجر مع البحث.';

  @override
  String get noStoresTapAdd => 'لا توجد متاجر بعد. اضغط + للإضافة.';

  @override
  String get noProducts => 'لا توجد منتجات بعد.';

  @override
  String get noProductsYet => 'لا توجد منتجات بعد';

  @override
  String get tapToAddFirstProduct => 'اضغط + لإضافة منتجك الأول';

  @override
  String get noProductsMatchSearch => 'لا تتطابق المنتجات مع البحث';

  @override
  String get tryDifferentSearch => 'جرب مصطلح بحث مختلف';

  @override
  String get noUsers => 'لا يوجد مستخدمون بعد.';

  @override
  String get confirmDelete => 'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String confirmDeleteItem(String name) {
    return 'هل أنت متأكد من حذف \"$name\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get deleteUser => 'حذف المستخدم';

  @override
  String get deleteProduct => 'حذف المنتج';

  @override
  String get deleteProject => 'حذف المشروع';

  @override
  String confirmDeleteProject(String name) {
    return 'هل أنت متأكد من حذف \"$name\"؟ سيتم إلغاء تعيين المستخدمين المعينين لهذا المشروع. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get deleteOrder => 'حذف الطلب';

  @override
  String get display => 'عرض';

  @override
  String get approveOrder => 'الموافقة على الطلب';

  @override
  String get approveSupplementaryRequest => 'الموافقة على الطلب الإضافي';

  @override
  String get refuseSupplementaryRequest => 'رفض الطلب الإضافي';

  @override
  String get refuseSupplementaryRequestQuestion => 'رفض هذا الطلب الإضافي؟';

  @override
  String get selectStoreToDeduct => 'اختر المتجر لخصم المخزون منه:';

  @override
  String get stockDeductedFromStore => 'سيتم خصم المخزون من هذا المتجر.';

  @override
  String get orderApproved => 'تمت الموافقة على الطلب. تم خصم المخزون.';

  @override
  String get orderDeleted => 'تم حذف الطلب.';

  @override
  String get rejectOrder => 'رفض الطلب';

  @override
  String get rejectOrderQuestion => 'رفض هذا الطلب؟ سيتم استعادة حصة المشروع.';

  @override
  String get orderRejected => 'تم رفض الطلب. تم استعادة حصة المشروع.';

  @override
  String get supplementaryRequestApproved => 'تمت الموافقة على الطلب الإضافي';

  @override
  String get supplementaryRequestRefused => 'تم رفض الطلب الإضافي';

  @override
  String get noSupplementaryRequests => 'لا توجد طلبات إضافية';

  @override
  String get noStoresAvailable => 'لا توجد متاجر متاحة';

  @override
  String get productsLabel => 'المنتجات:';

  @override
  String get productsAdditional => 'المنتجات (كميات إضافية):';

  @override
  String get user => 'المستخدم:';

  @override
  String get order => 'الطلب';

  @override
  String get orderStatusPending => 'قيد الانتظار';

  @override
  String get orderStatusCompleted => 'مكتمل';

  @override
  String get orderStatusRejected => 'مرفوض';

  @override
  String get orderQtyLabelProject => '(من المشروع)';

  @override
  String get orderQtyLabelSupplementary => '(إضافي)';

  @override
  String get orderDate => 'تاريخ الطلب:';

  @override
  String orderDateValue(String date) {
    return 'تاريخ الطلب: $date';
  }

  @override
  String projectLabel(String name) {
    return 'المشروع: $name';
  }

  @override
  String userLabel(String name) {
    return 'المستخدم: $name';
  }

  @override
  String get approvedQuantities => 'الكميات المعتمدة (من المسؤول):';

  @override
  String get noProductsLabel => 'لا توجد منتجات';

  @override
  String get myOrders => 'طلباتي';

  @override
  String get newOrder => 'طلب جديد';

  @override
  String get addProductSmall => 'إضافة منتج';

  @override
  String get allProductsAdded => 'تمت إضافة جميع المنتجات.';

  @override
  String get addAtLeastOneProduct =>
      'أضف منتجاً واحداً على الأقل بكمية أكبر من 0';

  @override
  String get orderPlacedSuccess => 'تم تقديم الطلب بنجاح';

  @override
  String get placeOrder => 'تقديم الطلب';

  @override
  String get supplementary => 'إضافي';

  @override
  String notesLabel(String notes) {
    return 'ملاحظات: $notes';
  }

  @override
  String get noOrdersMatch => 'لا تتطابق طلباتك مع البحث.';

  @override
  String get noProjectsMatch => 'لا تتطابق المشاريع مع البحث.';

  @override
  String get noProjectsTapAdd => 'لا توجد مشاريع بعد. اضغط + للإضافة.';

  @override
  String get addDamagedProduct => 'إضافة منتج تالف';

  @override
  String get allProductsAlreadyAdded => 'تمت إضافة جميع المنتجات بالفعل.';

  @override
  String get addProductsStoresFirst => 'أضف المنتجات والمتاجر والمشاريع أولاً.';

  @override
  String variantsLabel(String unit) {
    return 'المتغيرات ($unit)';
  }

  @override
  String editItem(String name) {
    return 'تعديل $name';
  }

  @override
  String get maxQty => 'الحد الأقصى:';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get addVariants => 'إضافة متغيرات';

  @override
  String get other => 'آخر';

  @override
  String get done => 'تم';

  @override
  String get addOtherVariant => 'إضافة متغير آخر';

  @override
  String get selectCategory => 'اختر الفئة';

  @override
  String get browseImage => 'تصفح الصورة من الكمبيوتر';

  @override
  String get editProduct => 'تعديل المنتج';

  @override
  String get nameArOptional => 'الاسم بالعربية (اختياري)';

  @override
  String get productImageSection => 'الصورة';

  @override
  String get unitRequired => 'الوحدة *';

  @override
  String get unitHint => 'مثال: قطعة، كجم، م²';

  @override
  String get categoryRequired => 'الفئة *';

  @override
  String get productVariantsTitle => 'المتغيرات';

  @override
  String get selectCategoryFirstForVariants => 'اختر فئة أعلاه لإضافة متغيرات';

  @override
  String get variantNameLabel => 'اسم المتغير';

  @override
  String get variantNameHint => 'مثال: مخصص 100';

  @override
  String get addVariantsDescription => 'اختر من القائمة أو أضف اسماً مخصصاً';

  @override
  String get tapToSelectImage => 'اضغط لاختيار صورة';

  @override
  String get productCategoryRetainingWall => 'نظام الجدران الاستنادية';

  @override
  String get productCategoryGeocell => 'جيوسيل';

  @override
  String get productCategoryGeogrid => 'شبكة جيوسيدر';

  @override
  String get productCategoryOther => 'أخرى';

  @override
  String get roleUser => 'مستخدم';

  @override
  String get roleAdmin => 'مسؤول';

  @override
  String get roleWarehouse => 'مستخدم المستودع';

  @override
  String get none => '-- لا يوجد --';

  @override
  String get description => 'الوصف';

  @override
  String get owner => 'المالك';

  @override
  String get usersAssigned => 'المستخدمون المعينون';

  @override
  String get deleteOrderLabel => 'حذف الطلب';

  @override
  String get approved => 'معتمد';

  @override
  String get refused => 'مرفوض';

  @override
  String get reason => 'السبب';

  @override
  String get reasonRequired => 'السبب *';

  @override
  String get damagedProductAdded => 'تم إضافة المنتج التالف';

  @override
  String get noDamagedProducts => 'لا توجد منتجات تالفة بعد';

  @override
  String get distributionDateLabel => 'تاريخ التوزيع:';

  @override
  String get createdDate => 'تاريخ الإنشاء:';

  @override
  String get validatedDate => 'تاريخ التحقق:';

  @override
  String get approvedDate => 'تاريخ الموافقة:';

  @override
  String get materialRequest => 'طلب المواد:';

  @override
  String get creationDate => 'تاريخ الإنشاء:';

  @override
  String get productCreationDate => 'تاريخ إنشاء المنتج:';

  @override
  String get returnDateByUser => 'تاريخ الإرجاع من المستخدم:';

  @override
  String get cannotDeleteItem => 'لا يمكن حذف هذا العنصر';

  @override
  String get deleteQuestion => 'حذف';

  @override
  String deleteItemQuestion(String type) {
    return 'حذف هذا $type؟';
  }

  @override
  String get deletedSuccess => 'تم الحذف بنجاح';

  @override
  String get category => 'الفئة';

  @override
  String get availableColors => 'المتغيرات المتوفرة';

  @override
  String get unit => 'الوحدة';

  @override
  String get manufacturer => 'الشركة المصنعة';

  @override
  String get distributor => 'الموزع';

  @override
  String get storesDepots => 'المتاجر / المستودعات';

  @override
  String get projectsTitle => 'المشاريع';

  @override
  String get projectsManagement => 'إدارة المشاريع';

  @override
  String get usersManagement => 'إدارة المستخدمين';

  @override
  String get noUsersTapAdd => 'لا يوجد مستخدمون بعد. اضغط + للإضافة.';

  @override
  String get noUsersMatch => 'لا يتطابق المستخدمون مع البحث.';

  @override
  String get deactivate => 'إلغاء التفعيل';

  @override
  String get activate => 'تفعيل';

  @override
  String confirmDeleteDistribution(String name) {
    return 'حذف التوزيع \"$name\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String refuseDistributionQuestion(String name) {
    return 'رفض التوزيع \"$name\"؟ لن يتم خصم أي مخزون.';
  }

  @override
  String validateDistributionQuestion(String name) {
    return 'التحقق من التوزيع \"$name\"؟ سيتم خصم المخزون من المتجر.';
  }

  @override
  String get orderApprovedCreateDist =>
      'تمت الموافقة على الطلب – إنشاء التوزيع';

  @override
  String distributionDateValue(String date) {
    return 'تاريخ التوزيع: $date';
  }

  @override
  String get approveReturn => 'الموافقة على الإرجاع';

  @override
  String get approveDamagedProduct => 'الموافقة على المنتج التالف';

  @override
  String approveDamagedProductQuestion(String name, int qty) {
    return 'الموافقة على \"$name\" (الكمية: $qty)؟ سيتم خصم المخزون من المتجر.';
  }

  @override
  String get totalGlobalStock => 'إجمالي المخزون العالمي';

  @override
  String get deleteStore => 'حذف المتجر';

  @override
  String addQuantityFor(String name) {
    return 'إضافة كمية - $name';
  }

  @override
  String get addStock => 'إضافة مخزون';

  @override
  String get editStock => 'تعديل المخزون';

  @override
  String get editStockSelectedVariant => 'المتغير المختار';

  @override
  String get deleteStock => 'حذف المخزون';

  @override
  String get updateQuantity => 'تحديث الكمية';

  @override
  String get addProductToReturn => 'إضافة منتج للإرجاع';

  @override
  String get newReturn => 'إرجاع جديد';

  @override
  String get pleaseSelectCategory => 'يرجى اختيار فئة';

  @override
  String imageUploadFailedSaving(String type) {
    return 'فشل تحميل الصورة. الحفظ مع صورة $type.';
  }

  @override
  String get qtyLabel => 'الكمية:';

  @override
  String get requested => 'مطلوب';

  @override
  String get distributed => 'موزع';

  @override
  String get stockRecordDeleted => 'تم حذف سجل المخزون';

  @override
  String get noStockMatchSearch => 'لا تتطابق سجلات المخزون مع البحث.';

  @override
  String imageUploadFailed(String type) {
    return 'فشل تحميل الصورة. الحفظ مع صورة $type.';
  }

  @override
  String get stockDetails => 'تفاصيل المخزون';

  @override
  String deleteStockRecordQuestion(String product, String store, String qty) {
    return 'حذف سجل المخزون لـ \"$product\" في $store؟ الكمية: $qty. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get noStockYet => 'لا توجد سجلات مخزون بعد.';

  @override
  String get tapToAddStock => 'اضغط + لإضافة مخزون لمنتج في متجر.';

  @override
  String get stockManagement => 'إدارة المخزون';

  @override
  String stockDistinctProductsCount(int count) {
    return 'المنتجات في المخزون: $count';
  }

  @override
  String stockSearchMatchCount(int count) {
    return 'تطابق البحث: $count';
  }

  @override
  String get searchStockHint => 'بحث المخزون...';

  @override
  String get storesManagement => 'إدارة المتاجر';

  @override
  String get location => 'الموقع';

  @override
  String get locationOnMaps => 'الموقع على الخريطة';

  @override
  String get locationMapsHint => 'العنوان، الإحداثيات، أو رابط خرائط Google';

  @override
  String get enterLocationForMaps => 'أدخل موقعاً أولاً';

  @override
  String get mapsOpenFailed =>
      'تعذر فتح الخرائط. تحقق من الرابط أو أعد المحاولة.';

  @override
  String get deleteOrderRestoreStock =>
      'حذف هذا الطلب؟ سيتم استعادة المخزون للمتجر.';

  @override
  String get deleteOrderSimple => 'حذف هذا الطلب؟';

  @override
  String get reject => 'رفض';

  @override
  String get addProductsAndStoresFirst => 'أضف المنتجات والمتاجر أولاً.';

  @override
  String get variant => 'المتغير';

  @override
  String get variantOrColor => 'المتغيرات';

  @override
  String get color => 'المتغيرات';

  @override
  String get addProject => 'إضافة مشروع';

  @override
  String get editProject => 'تعديل المشروع';

  @override
  String get nameRequired => 'الاسم *';

  @override
  String get nameEnglishRequired => 'الاسم بالإنجليزية *';

  @override
  String get projectOwner => 'صاحب المشروع';

  @override
  String get projectOwnerArabic => 'صاحب المشروع (عربي)';

  @override
  String get projectBoqDate => 'تاريخ B.O.Q';

  @override
  String get projectBoqCreationDateRequired => 'تاريخ إنشاء B.O.Q *';

  @override
  String get projectLastEditDateLabel => 'آخر تحديث للمشروع';

  @override
  String get productsQuantitiesHint =>
      'المنتجات (الكميات التي يمكن للمستخدمين طلبها)';

  @override
  String get required => 'مطلوب';

  @override
  String get maxQuantityUsersCanOrder =>
      'الحد الأقصى للكمية (يمكن للمستخدمين الطلب)';

  @override
  String get selectProduct => 'اختر منتجاً...';

  @override
  String get status => 'الحالة';

  @override
  String get addStore => 'إضافة متجر';

  @override
  String get editStore => 'تعديل المتجر';

  @override
  String get appTitle => 'إدارة المخزون';

  @override
  String get noItemsMatchSearch => 'لا تتطابق العناصر مع البحث.';

  @override
  String get materialRequestLabel => 'طلب المواد:';

  @override
  String get andMore => '... والمزيد';

  @override
  String get retryButton => 'إعادة المحاولة';

  @override
  String get ok => 'موافق';

  @override
  String get selectProductsQuantities => 'اختر المنتجات والكميات';

  @override
  String get noProductsAvailableForProject => 'لا توجد منتجات متاحة لمشروعك';

  @override
  String get contactAdminAddProducts =>
      'تواصل مع المسؤول لإضافة منتجات لمشروعك';

  @override
  String get quantityAddedSuccess => 'تمت إضافة الكمية بنجاح';

  @override
  String get couldNotLoadProduct => 'تعذر تحميل المنتج';

  @override
  String get viewProduct => 'عرض المنتج';

  @override
  String get selectStoreUndamagedProducts =>
      'اختر المتجر الذي ستُضاف إليه المنتجات السليمة:';

  @override
  String get goodStoreOriginDamagedSelected =>
      'سليم → متجر المنشأ | تالف → المتجر المحدد';

  @override
  String get returnApprovedUndamagedAdded =>
      'تمت الموافقة على الإرجاع. تمت إضافة المنتجات السليمة للمستودع.';

  @override
  String get approveAddUndamagedWarehouse => 'الموافقة (إضافة السليم للمستودع)';

  @override
  String get returnsFromUsersAppear => 'ستظهر إرجاعات المستخدمين هنا.';

  @override
  String get noReturnsYet => 'لا توجد مرتجعات بعد.';

  @override
  String get returnSubmittedSuccess => 'تم تقديم الإرجاع بنجاح';

  @override
  String get submitReturn => 'تقديم الإرجاع';

  @override
  String get myReturns => 'مرتجعاتي';

  @override
  String get quantityLabel => 'الكمية:';

  @override
  String get reasonLabel => 'السبب:';

  @override
  String get storeLabel => 'المتجر:';

  @override
  String get notesLabelShort => 'ملاحظات:';

  @override
  String get goodCondition => 'سليم';

  @override
  String get damagedCondition => 'تالف';

  @override
  String get noStoresAddFirst => 'لا توجد متاجر متاحة. أضف متاجر أولاً.';

  @override
  String get goodConditionReturnOrigin =>
      'المنتجات السليمة تعود لمتجرها الأصلي (من إعدادات المنتج).';

  @override
  String get selectStoreDamagedFallback =>
      'اختر متجراً للمنتجات التالفة وكبديل إذا لم يكن للمنتج متجر:';

  @override
  String get supplementaryRequestsTitle => 'الطلبات الإضافية';

  @override
  String get damagedProduct => 'منتج تالف';

  @override
  String get stockChange => 'تغيير المخزون';

  @override
  String get reportDateByUser => 'تاريخ التقرير من المستخدم:';

  @override
  String get orderDateRequired => 'تاريخ الطلب *';

  @override
  String noItemsFound(String type) {
    return 'لم يتم العثور على $type.';
  }

  @override
  String get quantityToAdd => 'الكمية المطلوب إضافتها';

  @override
  String get storeRequired => 'المتجر *';

  @override
  String get validationRequiredByAdmin => 'يتطلب التحقق من المسؤول فقط';

  @override
  String get selectProductsToReturn => 'اختر المنتجات والكميات للإرجاع';

  @override
  String get conditionLabel => 'الحالة';

  @override
  String userRequestedAdditionalQuantities(String name) {
    return 'طلب $name كميات إضافية';
  }

  @override
  String get searchReturnsHint => 'بحث المرتجعات...';

  @override
  String get noReturnsMatch => 'لا تتطابق المرتجعات مع البحث.';

  @override
  String get requestLabel => 'طلب';

  @override
  String get userFallback => 'المستخدم';

  @override
  String get addUser => 'إضافة مستخدم';

  @override
  String get editUser => 'تعديل المستخدم';

  @override
  String get name => 'الاسم';

  @override
  String get role => 'الدور';

  @override
  String get projectOptional => 'المشروع (اختياري)';

  @override
  String get minimum6Characters => '6 أحرف على الأقل';

  @override
  String maxQtyFormatted(String max, String unit) {
    return 'الحد الأقصى: $max $unit';
  }

  @override
  String get notAssignedToProject =>
      'لم يتم تعيينك لأي مشروع. تواصل مع المسؤول.';

  @override
  String approvedByLabel(String name) {
    return 'اعتمد من: $name';
  }

  @override
  String createdByLabel(String name) {
    return 'أنشئ من: $name';
  }

  @override
  String validatedByLabel(String name) {
    return 'تحقق من: $name';
  }

  @override
  String statusWithValue(String status) {
    return 'الحالة: $status';
  }

  @override
  String returnWithProject(String project) {
    return 'مرتجع • $project';
  }

  @override
  String get returnItem => 'مرتجع';

  @override
  String get searchDamagedHint => 'بحث في التالف...';

  @override
  String get noDamagedProductsReportedYet => 'لم يُبلّغ عن منتجات تالفة بعد';

  @override
  String get yourDamagedReportsWillAppear => 'ستظهر تقاريرك هنا';

  @override
  String extraQuantityPart(String qty) {
    return '(إضافي: +$qty)';
  }

  @override
  String get noApprovedOrdersToDistribute => 'لا توجد طلبات معتمدة للتوزيع';

  @override
  String get whenAdminApprovesOrderHint =>
      'عندما يوافق المسؤول على طلب، سيظهر هنا مع الكميات.\nاستخدم + لإنشاء توزيع يدوياً.';

  @override
  String orderNumberPrefix(String prefix) {
    return 'طلب #$prefix...';
  }

  @override
  String orderCardProductsSummary(int count, int total) {
    return '$count منتجات • الإجمالي $total';
  }

  @override
  String get productsRequiredLabel => 'المنتجات *';

  @override
  String qtyWithOptionalColor(String qty, String suffix) {
    return 'الكمية: $qty$suffix';
  }

  @override
  String get imageUploadFailedSavingExisting =>
      'فشل تحميل الصورة. جاري الحفظ مع الصورة الحالية.';

  @override
  String get imageUploadFailedSavingNo =>
      'فشل تحميل الصورة. جاري الحفظ بدون صورة.';

  @override
  String get returnsEmptySubtitle =>
      'ستظهر مرتجعاتك هنا.\nاضغط + لإنشاء مرتجع جديد.';

  @override
  String get administratorDisplayName => 'المسؤول';

  @override
  String get validatedStatus => 'تم التحقق';

  @override
  String qtyReasonStatusLine(String qty, String reason, String status) {
    return 'الكمية: $qty • $reason • $status';
  }

  @override
  String reportRowItem(int n) {
    return 'عنصر $n';
  }

  @override
  String get reportFieldCreatedAt => 'تاريخ الإنشاء';

  @override
  String get reportFieldUpdatedAt => 'تاريخ التحديث';

  @override
  String get reportFieldApprovedAt => 'تاريخ الموافقة';

  @override
  String get reportFieldApprovedBy => 'اعتمد من';

  @override
  String get reportFieldReportedBy => 'أبلغ من';

  @override
  String get reportFieldProductId => 'معرف المنتج';

  @override
  String get reportFieldProjectId => 'معرف المشروع';

  @override
  String get reportFieldStoreId => 'معرف المتجر';

  @override
  String get reportFieldUserId => 'معرف المستخدم';

  @override
  String get reportFieldDeliveryDate => 'تاريخ التسليم';

  @override
  String get reportFieldSerialNumber => 'الرقم التسلسلي';

  @override
  String get reportFieldBonAlimentation => 'مرجع طلب المواد';

  @override
  String get reportFieldType => 'النوع';

  @override
  String get reportFieldPhone => 'الهاتف';

  @override
  String get reportFieldAddress => 'العنوان';

  @override
  String get reportFieldImage => 'الصورة';

  @override
  String get reportFieldRole => 'الدور';

  @override
  String get reportFieldProduct => 'المنتج';

  @override
  String get reportFieldColor => 'المتغيرات';

  @override
  String get reportFieldCondition => 'الحالة';

  @override
  String get reportFieldExtraQuantity => 'الكمية الإضافية';

  @override
  String get reportFieldOrderId => 'معرف الطلب';

  @override
  String get reportFieldReturnId => 'معرف الإرجاع';

  @override
  String get reportFieldDistributionId => 'معرف التوزيع';

  @override
  String get reportFieldQuantity => 'الكمية';

  @override
  String get reportFieldTotal => 'الإجمالي';

  @override
  String get reportFieldPrice => 'السعر';

  @override
  String get reportFieldAmount => 'المبلغ';

  @override
  String get reportFieldDetails => 'التفاصيل';

  @override
  String get reportFieldTitle => 'العنوان';

  @override
  String get reportFieldCode => 'الرمز';

  @override
  String get reportFieldReference => 'المرجع';

  @override
  String get reportFieldLocation => 'الموقع';

  @override
  String get reportFieldDate => 'التاريخ';

  @override
  String get reportFieldTime => 'الوقت';

  @override
  String get reportFieldComment => 'تعليق';

  @override
  String get reportFieldPriority => 'الأولوية';

  @override
  String get reportFieldSource => 'المصدر';

  @override
  String get reportFieldDestination => 'الوجهة';

  @override
  String get reportFieldValue => 'القيمة';

  @override
  String get reportFieldKey => 'حقل';

  @override
  String get reportFieldNotes => 'ملاحظات';

  @override
  String reportFieldUnknown(String key) {
    return '$key';
  }

  @override
  String get distributionSingle => 'توزيع';

  @override
  String get removeTooltip => 'إزالة';

  @override
  String get qtyShort => 'كمية';

  @override
  String allocatedWithUnit(String allocated, String unit) {
    return 'المخصص: $allocated $unit';
  }

  @override
  String allocatedDropdownSuffix(String n) {
    return ' (المخصص: $n)';
  }

  @override
  String get supplementaryRequestMoreHint =>
      'يمكنك طلب المزيد (كمية إضافية، تتطلب موافقة المسؤول)';

  @override
  String orderQuantitySupplementaryHint(String example) {
    return 'الحد الأدنى: 1، مثلاً $example للكمية الإضافية';
  }

  @override
  String allocatedSummaryWithExtra(
      String allocated, String unit, String extra) {
    return 'المخصص: $allocated $unit • +$extra إضافي';
  }

  @override
  String productNameWithMaxQty(String name, String max) {
    return '$name (الحد الأقصى: $max)';
  }

  @override
  String maxQtyHintNumber(String max) {
    return 'الحد الأقصى: $max';
  }
}
