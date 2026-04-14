// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get viewDetails => 'View details';

  @override
  String get close => 'Close';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get warehouse => 'Warehouse';

  @override
  String get warehouseDashboard => 'Warehouse Dashboard';

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get stock => 'Stock';

  @override
  String get warehouseStockEntryBannerTitle => 'Warehouse added stock';

  @override
  String warehouseStockEntryLine(
      String productName, String quantity, String storeName) {
    return '$productName · +$quantity · $storeName';
  }

  @override
  String warehouseStockAddedOnCard(String quantity) {
    return '+$quantity (warehouse)';
  }

  @override
  String get projects => 'Projects';

  @override
  String get orders => 'Orders';

  @override
  String get myDistributions => 'My Distributions';

  @override
  String get totalStock => 'Total Stock';

  @override
  String get reports => 'Reports';

  @override
  String get selectReportType => 'Select a report type';

  @override
  String get searchReportsHint => 'Search reports...';

  @override
  String get noReportTypesMatchSearch => 'No report types match your search.';

  @override
  String get searchReportHint => 'Search report...';

  @override
  String get reportValidatedDistributions => 'Validated Distributions';

  @override
  String get reportValidatedDistributionsMenu => 'Validated\nDistributions';

  @override
  String get reportApprovedReturns => 'Approved Returns';

  @override
  String get reportApprovedReturnsMenu => 'Approved\nReturns';

  @override
  String get reportStockHistory => 'Stock History';

  @override
  String get reportStockHistoryMenu => 'Stock\nHistory';

  @override
  String get reportProjects => 'Projects';

  @override
  String get reportProjectsMenu => 'Projects';

  @override
  String get reportExportProjectPdf => 'Export PDF';

  @override
  String get projectSavedShort => 'Project saved';

  @override
  String get quantityRest => 'Rest';

  @override
  String get reportDeleteTypeDistribution => 'distribution';

  @override
  String get reportDeleteTypeOrder => 'order';

  @override
  String get reportDeleteTypeReturn => 'return';

  @override
  String get reportDeleteTypeDamagedProduct => 'damaged product record';

  @override
  String get reportDeleteTypeStockEntry => 'stock history entry';

  @override
  String get damagedProducts => 'Damaged Products';

  @override
  String get damagedProductsMenu => 'Damaged\nProducts';

  @override
  String get returns => 'Returns';

  @override
  String get damages => 'Damages';

  @override
  String get users => 'Users';

  @override
  String get stores => 'Stores';

  @override
  String get products => 'Products';

  @override
  String get distributions => 'Distributions';

  @override
  String get supplementaryRequests => 'Supplementary Requests';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get signIn => 'Sign in';

  @override
  String get retry => 'Retry';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get createDistribution => 'Create Distribution';

  @override
  String get addProduct => 'Add Product';

  @override
  String get product => 'Product';

  @override
  String get quantity => 'Quantity';

  @override
  String get project => 'Project';

  @override
  String get store => 'Store';

  @override
  String get depot => 'Depot';

  @override
  String get sourceStoreDepot => 'Source (Store/Depot)';

  @override
  String get selectLocationHint =>
      'Select the location with stock to distribute from';

  @override
  String get materialRequestOptional => 'Material Request (optional)';

  @override
  String get materialRequestHint => 'Leave empty for auto-generated';

  @override
  String get distributionDate => 'Distribution date';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get selectProjectFirst => 'Select a project first.';

  @override
  String get noProductsRequested =>
      'No products requested by users for this project.';

  @override
  String get pleaseSelectProjectStore =>
      'Please select project, store, and add at least one product.';

  @override
  String distributionCreated(String mr) {
    return 'Distribution created. Material Request: $mr';
  }

  @override
  String get noProductsAdded => 'No products added. Tap Add to add products.';

  @override
  String get selectProjectFirstShort => 'Select project first';

  @override
  String get noProductsRequestedShort => 'No products requested';

  @override
  String get pleaseEnterQuantity => 'Please enter a quantity greater than 0';

  @override
  String get deleteDistribution => 'Delete Distribution';

  @override
  String get refuseDistribution => 'Refuse Distribution';

  @override
  String get validateDistribution => 'Validate Distribution';

  @override
  String get approve => 'Approve';

  @override
  String get validate => 'Validate';

  @override
  String get refuse => 'Refuse';

  @override
  String get search => 'Search';

  @override
  String searchHint(String what) {
    return 'Search $what...';
  }

  @override
  String get searchUsersHint => 'Search users...';

  @override
  String get searchProductsHint => 'Search products...';

  @override
  String get searchOrdersHint => 'Search orders...';

  @override
  String get searchProjectsHint => 'Search projects...';

  @override
  String get searchStoresHint => 'Search stores...';

  @override
  String get searchDistributionsHint => 'Search distributions...';

  @override
  String get noDistributionsMatch => 'No distributions match your search.';

  @override
  String get noDistributionsCreateHint =>
      'No distributions yet. Create distributions via the API or add a form.';

  @override
  String get notifications => 'Notifications';

  @override
  String distributionAccepted(String bon) {
    return 'Distribution accepted. Material Request: $bon';
  }

  @override
  String distributionRefused(String bon) {
    return 'Distribution refused. Material Request: $bon';
  }

  @override
  String get noDistributions => 'No distributions yet.';

  @override
  String get noOrders => 'No orders yet.';

  @override
  String get noOrdersYetUser => 'No orders yet.\nYour orders will appear here.';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get noProjects => 'No projects yet.';

  @override
  String get noStores => 'No stores yet.';

  @override
  String get noStoresMatch => 'No stores match your search.';

  @override
  String get noStoresTapAdd => 'No stores yet. Tap + to add one.';

  @override
  String get noProducts => 'No products yet.';

  @override
  String get noProductsYet => 'No products yet';

  @override
  String get tapToAddFirstProduct => 'Tap + to add your first product';

  @override
  String get noProductsMatchSearch => 'No products match your search';

  @override
  String get tryDifferentSearch => 'Try a different search term';

  @override
  String get noUsers => 'No users yet.';

  @override
  String get confirmDelete => 'Are you sure? This action cannot be undone.';

  @override
  String confirmDeleteItem(String name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get deleteUser => 'Delete User';

  @override
  String get deleteProduct => 'Delete Product';

  @override
  String get deleteProject => 'Delete Project';

  @override
  String confirmDeleteProject(String name) {
    return 'Are you sure you want to delete \"$name\"? Users assigned to this project will be unassigned. This action cannot be undone.';
  }

  @override
  String get deleteOrder => 'Delete Order';

  @override
  String get display => 'Display';

  @override
  String get approveOrder => 'Approve Order';

  @override
  String get approveSupplementaryRequest => 'Approve supplementary request';

  @override
  String get refuseSupplementaryRequest => 'Refuse supplementary request';

  @override
  String get refuseSupplementaryRequestQuestion =>
      'Refuse this supplementary request?';

  @override
  String get selectStoreToDeduct => 'Select store to deduct stock from:';

  @override
  String get stockDeductedFromStore =>
      'Stock will be deducted from this store.';

  @override
  String get orderApproved => 'Order approved. Stock deducted.';

  @override
  String get orderDeleted => 'Order deleted.';

  @override
  String get rejectOrder => 'Reject Order';

  @override
  String get rejectOrderQuestion =>
      'Reject this order? The project quota will be restored.';

  @override
  String get orderRejected => 'Order rejected. Project quota restored.';

  @override
  String get supplementaryRequestApproved => 'Supplementary request approved';

  @override
  String get supplementaryRequestRefused => 'Supplementary request refused';

  @override
  String get noSupplementaryRequests => 'No supplementary requests';

  @override
  String get noStoresAvailable => 'No stores available';

  @override
  String get productsLabel => 'Products:';

  @override
  String get productsAdditional => 'Products (additional quantities):';

  @override
  String get user => 'User:';

  @override
  String get order => 'Order';

  @override
  String get orderStatusPending => 'Pending';

  @override
  String get orderStatusCompleted => 'Completed';

  @override
  String get orderStatusRejected => 'Rejected';

  @override
  String get orderQtyLabelProject => '(project)';

  @override
  String get orderQtyLabelSupplementary => '(supplementary)';

  @override
  String get orderDate => 'Order date:';

  @override
  String orderDateValue(String date) {
    return 'Order date: $date';
  }

  @override
  String projectLabel(String name) {
    return 'Project: $name';
  }

  @override
  String userLabel(String name) {
    return 'User: $name';
  }

  @override
  String get approvedQuantities => 'Approved quantities (by admin):';

  @override
  String get noProductsLabel => 'No products';

  @override
  String get myOrders => 'My Orders';

  @override
  String get newOrder => 'New Order';

  @override
  String get addProductSmall => 'Add product';

  @override
  String get allProductsAdded => 'All products have been added.';

  @override
  String get addAtLeastOneProduct =>
      'Add at least one product with quantity > 0';

  @override
  String get orderPlacedSuccess => 'Order placed successfully';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get supplementary => 'Supplementary';

  @override
  String notesLabel(String notes) {
    return 'Notes: $notes';
  }

  @override
  String get noOrdersMatch => 'No orders match your search.';

  @override
  String get noProjectsMatch => 'No projects match your search.';

  @override
  String get noProjectsTapAdd => 'No projects yet. Tap + to add one.';

  @override
  String get addDamagedProduct => 'Add Damaged Product';

  @override
  String get allProductsAlreadyAdded => 'All products are already added.';

  @override
  String get addProductsStoresFirst =>
      'Add products, stores, and projects first.';

  @override
  String variantsLabel(String unit) {
    return 'Variants ($unit)';
  }

  @override
  String editItem(String name) {
    return 'Edit $name';
  }

  @override
  String get maxQty => 'Max qty:';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get addVariants => 'Add Variants';

  @override
  String get other => 'Other';

  @override
  String get done => 'Done';

  @override
  String get addOtherVariant => 'Add other variant';

  @override
  String get selectCategory => 'Select category';

  @override
  String get browseImage => 'Browse image from computer';

  @override
  String get editProduct => 'Edit Product';

  @override
  String get nameArOptional => 'Arabic name (optional)';

  @override
  String get productImageSection => 'Image';

  @override
  String get unitRequired => 'Unit *';

  @override
  String get unitHint => 'e.g. piece, kg, m²';

  @override
  String get categoryRequired => 'Category *';

  @override
  String get productVariantsTitle => 'Variants';

  @override
  String get selectCategoryFirstForVariants =>
      'Select a category above to add variants';

  @override
  String get variantNameLabel => 'Variant name';

  @override
  String get variantNameHint => 'e.g. Custom 100';

  @override
  String get addVariantsDescription =>
      'Select from predefined list or add custom';

  @override
  String get tapToSelectImage => 'Tap to select image';

  @override
  String get productCategoryRetainingWall => 'Retaining Wall System';

  @override
  String get productCategoryGeocell => 'Geocell';

  @override
  String get productCategoryGeogrid => 'Geogrid';

  @override
  String get productCategoryOther => 'Other';

  @override
  String get roleUser => 'User';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleWarehouse => 'Warehouse User';

  @override
  String get none => '-- None --';

  @override
  String get description => 'Description';

  @override
  String get owner => 'Owner';

  @override
  String get usersAssigned => 'Users assigned';

  @override
  String get deleteOrderLabel => 'Delete order';

  @override
  String get approved => 'Approved';

  @override
  String get refused => 'Refused';

  @override
  String get reason => 'Reason';

  @override
  String get reasonRequired => 'Reason *';

  @override
  String get damagedProductAdded => 'Damaged product added';

  @override
  String get noDamagedProducts => 'No damaged products yet';

  @override
  String get distributionDateLabel => 'Distribution date:';

  @override
  String get createdDate => 'Created date:';

  @override
  String get validatedDate => 'Validated date:';

  @override
  String get approvedDate => 'Approved date:';

  @override
  String get materialRequest => 'Material Request:';

  @override
  String get creationDate => 'Creation date:';

  @override
  String get productCreationDate => 'Product creation date:';

  @override
  String get returnDateByUser => 'Return date by user:';

  @override
  String get cannotDeleteItem => 'Cannot delete this item';

  @override
  String get deleteQuestion => 'Delete';

  @override
  String deleteItemQuestion(String type) {
    return 'Delete this $type?';
  }

  @override
  String get deletedSuccess => 'Deleted successfully';

  @override
  String get category => 'Category';

  @override
  String get availableColors => 'Available variants';

  @override
  String get unit => 'Unit';

  @override
  String get manufacturer => 'Manufacture';

  @override
  String get distributor => 'Distributor';

  @override
  String get storesDepots => 'Stores / Depots';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectsManagement => 'Projects Management';

  @override
  String get usersManagement => 'Users Management';

  @override
  String get noUsersTapAdd => 'No users yet. Tap + to add one.';

  @override
  String get noUsersMatch => 'No users match your search.';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get activate => 'Activate';

  @override
  String confirmDeleteDistribution(String name) {
    return 'Delete distribution \"$name\"? This action cannot be undone.';
  }

  @override
  String refuseDistributionQuestion(String name) {
    return 'Refuse distribution \"$name\"? This will not deduct any stock.';
  }

  @override
  String validateDistributionQuestion(String name) {
    return 'Validate distribution \"$name\"? This will deduct stock from the store.';
  }

  @override
  String get orderApprovedCreateDist => 'Order approved – Create distribution';

  @override
  String distributionDateValue(String date) {
    return 'Distribution date: $date';
  }

  @override
  String get approveReturn => 'Approve Return';

  @override
  String get approveDamagedProduct => 'Approve Damaged Product';

  @override
  String approveDamagedProductQuestion(String name, int qty) {
    return 'Approve \"$name\" (qty: $qty)? This will deduct stock from the store.';
  }

  @override
  String get totalGlobalStock => 'Total Global Stock';

  @override
  String get deleteStore => 'Delete Store';

  @override
  String addQuantityFor(String name) {
    return 'Add quantity - $name';
  }

  @override
  String get addStock => 'Add Stock';

  @override
  String get editStock => 'Edit Stock';

  @override
  String get editStockSelectedVariant => 'Selected variant';

  @override
  String get deleteStock => 'Delete Stock';

  @override
  String get updateQuantity => 'Update Quantity';

  @override
  String get addProductToReturn => 'Add product to return';

  @override
  String get newReturn => 'New Return';

  @override
  String get pleaseSelectCategory => 'Please select a category';

  @override
  String imageUploadFailedSaving(String type) {
    return 'Image upload failed. Saving with $type image.';
  }

  @override
  String get qtyLabel => 'Qty:';

  @override
  String get requested => 'Requested';

  @override
  String get distributed => 'Distributed';

  @override
  String get stockRecordDeleted => 'Stock record deleted';

  @override
  String get noStockMatchSearch => 'No stock records match your search.';

  @override
  String imageUploadFailed(String type) {
    return 'Image upload failed. Saving with $type image.';
  }

  @override
  String get stockDetails => 'Stock Details';

  @override
  String deleteStockRecordQuestion(String product, String store, String qty) {
    return 'Delete stock record for \"$product\" at $store? Quantity: $qty. This action cannot be undone.';
  }

  @override
  String get noStockYet => 'No stock records yet.';

  @override
  String get tapToAddStock => 'Tap + to add stock for a product in a store.';

  @override
  String get stockManagement => 'Stock Management';

  @override
  String stockDistinctProductsCount(int count) {
    return 'Products in stock: $count';
  }

  @override
  String stockSearchMatchCount(int count) {
    return 'Matches: $count';
  }

  @override
  String get searchStockHint => 'Search stock...';

  @override
  String get storesManagement => 'Stores Management';

  @override
  String get location => 'Location';

  @override
  String get locationOnMaps => 'Location on maps';

  @override
  String get locationMapsHint =>
      'Address, coordinates, or paste a Google Maps link';

  @override
  String get enterLocationForMaps => 'Enter a location first';

  @override
  String get mapsOpenFailed =>
      'Could not open maps. Check the link or try again.';

  @override
  String get deleteOrderRestoreStock =>
      'Delete this order? Stock will be restored to the store.';

  @override
  String get deleteOrderSimple => 'Delete this order?';

  @override
  String get reject => 'Reject';

  @override
  String get addProductsAndStoresFirst => 'Add products and stores first.';

  @override
  String get variant => 'Variant';

  @override
  String get variantOrColor => 'Variants';

  @override
  String get color => 'Variants';

  @override
  String get addProject => 'Add Project';

  @override
  String get editProject => 'Edit Project';

  @override
  String get nameRequired => 'Name *';

  @override
  String get nameEnglishRequired => 'Name (English) *';

  @override
  String get projectOwner => 'Project Owner';

  @override
  String get projectOwnerArabic => 'Project Owner (Arabic)';

  @override
  String get projectBoqDate => 'B.O.Q date';

  @override
  String get projectBoqCreationDateRequired => 'B.O.Q creation date *';

  @override
  String get projectLastEditDateLabel => 'Last project update';

  @override
  String get productsQuantitiesHint => 'Products (quantities users can order)';

  @override
  String get required => 'Required';

  @override
  String get maxQuantityUsersCanOrder => 'Max quantity (users can order)';

  @override
  String get selectProduct => 'Select product...';

  @override
  String get status => 'Status';

  @override
  String get addStore => 'Add Store';

  @override
  String get editStore => 'Edit Store';

  @override
  String get appTitle => 'Stock Management';

  @override
  String get noItemsMatchSearch => 'No items match your search.';

  @override
  String get materialRequestLabel => 'Material Request:';

  @override
  String get andMore => '... and more';

  @override
  String get retryButton => 'Retry';

  @override
  String get ok => 'OK';

  @override
  String get selectProductsQuantities => 'Select products and quantities';

  @override
  String get noProductsAvailableForProject =>
      'No products available for your project';

  @override
  String get contactAdminAddProducts =>
      'Contact your admin to add products to your project';

  @override
  String get quantityAddedSuccess => 'Quantity added successfully';

  @override
  String get couldNotLoadProduct => 'Could not load product';

  @override
  String get viewProduct => 'View product';

  @override
  String get selectStoreUndamagedProducts =>
      'Select store where undamaged products will be added:';

  @override
  String get goodStoreOriginDamagedSelected =>
      'Good → store of origin | Damaged → selected store';

  @override
  String get returnApprovedUndamagedAdded =>
      'Return approved. Undamaged products added to warehouse.';

  @override
  String get approveAddUndamagedWarehouse =>
      'Approve (add undamaged to warehouse)';

  @override
  String get returnsFromUsersAppear => 'Returns from users will appear here.';

  @override
  String get noReturnsYet => 'No returns yet.';

  @override
  String get returnSubmittedSuccess => 'Return submitted successfully';

  @override
  String get submitReturn => 'Submit Return';

  @override
  String get myReturns => 'My Returns';

  @override
  String get quantityLabel => 'Quantity:';

  @override
  String get reasonLabel => 'Reason:';

  @override
  String get storeLabel => 'Store:';

  @override
  String get notesLabelShort => 'Notes:';

  @override
  String get goodCondition => 'Good';

  @override
  String get damagedCondition => 'Damaged';

  @override
  String get noStoresAddFirst => 'No stores available. Add stores first.';

  @override
  String get goodConditionReturnOrigin =>
      'Good condition products return to their store of origin (from product config).';

  @override
  String get selectStoreDamagedFallback =>
      'Select store for damaged products and as fallback if product has no store:';

  @override
  String get supplementaryRequestsTitle => 'Supplementary requests';

  @override
  String get damagedProduct => 'Damaged product';

  @override
  String get stockChange => 'Stock change';

  @override
  String get reportDateByUser => 'Report date by user:';

  @override
  String get orderDateRequired => 'Order date *';

  @override
  String noItemsFound(String type) {
    return 'No $type found.';
  }

  @override
  String get quantityToAdd => 'Quantity to add';

  @override
  String get storeRequired => 'Store *';

  @override
  String get validationRequiredByAdmin => 'Validation required by Admin only';

  @override
  String get selectProductsToReturn =>
      'Select products and quantities to return';

  @override
  String get conditionLabel => 'Condition';

  @override
  String userRequestedAdditionalQuantities(String name) {
    return '$name requested additional quantities';
  }

  @override
  String get searchReturnsHint => 'Search returns...';

  @override
  String get noReturnsMatch => 'No returns match your search.';

  @override
  String get requestLabel => 'Request';

  @override
  String get userFallback => 'User';

  @override
  String get addUser => 'Add User';

  @override
  String get editUser => 'Edit User';

  @override
  String get name => 'Name';

  @override
  String get role => 'Role';

  @override
  String get projectOptional => 'Project (optional)';

  @override
  String get minimum6Characters => 'Minimum 6 characters';

  @override
  String maxQtyFormatted(String max, String unit) {
    return 'Max: $max $unit';
  }

  @override
  String get notAssignedToProject =>
      'You are not assigned to any project. Contact your admin.';

  @override
  String approvedByLabel(String name) {
    return 'Approved by: $name';
  }

  @override
  String createdByLabel(String name) {
    return 'Created by: $name';
  }

  @override
  String validatedByLabel(String name) {
    return 'Validated by: $name';
  }

  @override
  String statusWithValue(String status) {
    return 'Status: $status';
  }

  @override
  String returnWithProject(String project) {
    return 'Return • $project';
  }

  @override
  String get returnItem => 'Return';

  @override
  String get searchDamagedHint => 'Search damaged...';

  @override
  String get noDamagedProductsReportedYet => 'No damaged products reported yet';

  @override
  String get yourDamagedReportsWillAppear => 'Your reports will appear here';

  @override
  String extraQuantityPart(String qty) {
    return '(extra: +$qty)';
  }

  @override
  String get noApprovedOrdersToDistribute => 'No approved orders to distribute';

  @override
  String get whenAdminApprovesOrderHint =>
      'When admin approves an order, it will appear here with quantities.\nUse + to create a distribution manually.';

  @override
  String orderNumberPrefix(String prefix) {
    return 'Order #$prefix...';
  }

  @override
  String orderCardProductsSummary(int count, int total) {
    return '$count products • $total total';
  }

  @override
  String get productsRequiredLabel => 'Products *';

  @override
  String qtyWithOptionalColor(String qty, String suffix) {
    return 'Qty: $qty$suffix';
  }

  @override
  String get imageUploadFailedSavingExisting =>
      'Image upload failed. Saving with existing image.';

  @override
  String get imageUploadFailedSavingNo =>
      'Image upload failed. Saving without image.';

  @override
  String get returnsEmptySubtitle =>
      'Your returns will appear here.\nTap + to create a new return.';

  @override
  String get administratorDisplayName => 'Administrator';

  @override
  String get validatedStatus => 'Validated';

  @override
  String qtyReasonStatusLine(String qty, String reason, String status) {
    return 'Qty: $qty • $reason • $status';
  }

  @override
  String reportRowItem(int n) {
    return 'Item $n';
  }

  @override
  String get reportFieldCreatedAt => 'Created at';

  @override
  String get reportFieldUpdatedAt => 'Updated at';

  @override
  String get reportFieldApprovedAt => 'Approved at';

  @override
  String get reportFieldApprovedBy => 'Approved by';

  @override
  String get reportFieldReportedBy => 'Reported by';

  @override
  String get reportFieldProductId => 'Product ID';

  @override
  String get reportFieldProjectId => 'Project ID';

  @override
  String get reportFieldStoreId => 'Store ID';

  @override
  String get reportFieldUserId => 'User ID';

  @override
  String get reportFieldDeliveryDate => 'Delivery date';

  @override
  String get reportFieldSerialNumber => 'Serial number';

  @override
  String get reportFieldBonAlimentation => 'Material request ref.';

  @override
  String get reportFieldType => 'Type';

  @override
  String get reportFieldPhone => 'Phone';

  @override
  String get reportFieldAddress => 'Address';

  @override
  String get reportFieldImage => 'Image';

  @override
  String get reportFieldRole => 'Role';

  @override
  String get reportFieldProduct => 'Product';

  @override
  String get reportFieldColor => 'Variants';

  @override
  String get reportFieldCondition => 'Condition';

  @override
  String get reportFieldExtraQuantity => 'Extra quantity';

  @override
  String get reportFieldOrderId => 'Order ID';

  @override
  String get reportFieldReturnId => 'Return ID';

  @override
  String get reportFieldDistributionId => 'Distribution ID';

  @override
  String get reportFieldQuantity => 'Quantity';

  @override
  String get reportFieldTotal => 'Total';

  @override
  String get reportFieldPrice => 'Price';

  @override
  String get reportFieldAmount => 'Amount';

  @override
  String get reportFieldDetails => 'Details';

  @override
  String get reportFieldTitle => 'Title';

  @override
  String get reportFieldCode => 'Code';

  @override
  String get reportFieldReference => 'Reference';

  @override
  String get reportFieldLocation => 'Location';

  @override
  String get reportFieldDate => 'Date';

  @override
  String get reportFieldTime => 'Time';

  @override
  String get reportFieldComment => 'Comment';

  @override
  String get reportFieldPriority => 'Priority';

  @override
  String get reportFieldSource => 'Source';

  @override
  String get reportFieldDestination => 'Destination';

  @override
  String get reportFieldValue => 'Value';

  @override
  String get reportFieldKey => 'Field';

  @override
  String get reportFieldNotes => 'Notes';

  @override
  String reportFieldUnknown(String key) {
    return '$key';
  }

  @override
  String get distributionSingle => 'Distribution';

  @override
  String get removeTooltip => 'Remove';

  @override
  String get qtyShort => 'Qty';

  @override
  String allocatedWithUnit(String allocated, String unit) {
    return 'Allocated: $allocated $unit';
  }

  @override
  String allocatedDropdownSuffix(String n) {
    return ' (allocated: $n)';
  }

  @override
  String get supplementaryRequestMoreHint =>
      'You can request more (supplementary, requires admin approval)';

  @override
  String orderQuantitySupplementaryHint(String example) {
    return 'Min: 1, e.g. $example for supplementary';
  }

  @override
  String allocatedSummaryWithExtra(
      String allocated, String unit, String extra) {
    return 'Allocated: $allocated $unit • +$extra extra';
  }

  @override
  String productNameWithMaxQty(String name, String max) {
    return '$name (max: $max)';
  }

  @override
  String maxQtyHintNumber(String max) {
    return 'Max: $max';
  }
}
