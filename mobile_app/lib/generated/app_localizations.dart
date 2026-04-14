import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @warehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get warehouse;

  /// No description provided for @warehouseDashboard.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Dashboard'**
  String get warehouseDashboard;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @warehouseStockEntryBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Warehouse added stock'**
  String get warehouseStockEntryBannerTitle;

  /// No description provided for @warehouseStockEntryLine.
  ///
  /// In en, this message translates to:
  /// **'{productName} · +{quantity} · {storeName}'**
  String warehouseStockEntryLine(
      String productName, String quantity, String storeName);

  /// No description provided for @warehouseStockAddedOnCard.
  ///
  /// In en, this message translates to:
  /// **'+{quantity} (warehouse)'**
  String warehouseStockAddedOnCard(String quantity);

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @myDistributions.
  ///
  /// In en, this message translates to:
  /// **'My Distributions'**
  String get myDistributions;

  /// No description provided for @totalStock.
  ///
  /// In en, this message translates to:
  /// **'Total Stock'**
  String get totalStock;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @selectReportType.
  ///
  /// In en, this message translates to:
  /// **'Select a report type'**
  String get selectReportType;

  /// No description provided for @searchReportsHint.
  ///
  /// In en, this message translates to:
  /// **'Search reports...'**
  String get searchReportsHint;

  /// No description provided for @noReportTypesMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No report types match your search.'**
  String get noReportTypesMatchSearch;

  /// No description provided for @searchReportHint.
  ///
  /// In en, this message translates to:
  /// **'Search report...'**
  String get searchReportHint;

  /// No description provided for @reportValidatedDistributions.
  ///
  /// In en, this message translates to:
  /// **'Validated Distributions'**
  String get reportValidatedDistributions;

  /// No description provided for @reportValidatedDistributionsMenu.
  ///
  /// In en, this message translates to:
  /// **'Validated\nDistributions'**
  String get reportValidatedDistributionsMenu;

  /// No description provided for @reportApprovedReturns.
  ///
  /// In en, this message translates to:
  /// **'Approved Returns'**
  String get reportApprovedReturns;

  /// No description provided for @reportApprovedReturnsMenu.
  ///
  /// In en, this message translates to:
  /// **'Approved\nReturns'**
  String get reportApprovedReturnsMenu;

  /// No description provided for @reportStockHistory.
  ///
  /// In en, this message translates to:
  /// **'Stock History'**
  String get reportStockHistory;

  /// No description provided for @reportStockHistoryMenu.
  ///
  /// In en, this message translates to:
  /// **'Stock\nHistory'**
  String get reportStockHistoryMenu;

  /// No description provided for @reportProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get reportProjects;

  /// No description provided for @reportProjectsMenu.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get reportProjectsMenu;

  /// No description provided for @reportExportProjectPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get reportExportProjectPdf;

  /// No description provided for @projectSavedShort.
  ///
  /// In en, this message translates to:
  /// **'Project saved'**
  String get projectSavedShort;

  /// No description provided for @quantityRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get quantityRest;

  /// No description provided for @reportDeleteTypeDistribution.
  ///
  /// In en, this message translates to:
  /// **'distribution'**
  String get reportDeleteTypeDistribution;

  /// No description provided for @reportDeleteTypeOrder.
  ///
  /// In en, this message translates to:
  /// **'order'**
  String get reportDeleteTypeOrder;

  /// No description provided for @reportDeleteTypeReturn.
  ///
  /// In en, this message translates to:
  /// **'return'**
  String get reportDeleteTypeReturn;

  /// No description provided for @reportDeleteTypeDamagedProduct.
  ///
  /// In en, this message translates to:
  /// **'damaged product record'**
  String get reportDeleteTypeDamagedProduct;

  /// No description provided for @reportDeleteTypeStockEntry.
  ///
  /// In en, this message translates to:
  /// **'stock history entry'**
  String get reportDeleteTypeStockEntry;

  /// No description provided for @damagedProducts.
  ///
  /// In en, this message translates to:
  /// **'Damaged Products'**
  String get damagedProducts;

  /// No description provided for @damagedProductsMenu.
  ///
  /// In en, this message translates to:
  /// **'Damaged\nProducts'**
  String get damagedProductsMenu;

  /// No description provided for @returns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returns;

  /// No description provided for @damages.
  ///
  /// In en, this message translates to:
  /// **'Damages'**
  String get damages;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @stores.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get stores;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @distributions.
  ///
  /// In en, this message translates to:
  /// **'Distributions'**
  String get distributions;

  /// No description provided for @supplementaryRequests.
  ///
  /// In en, this message translates to:
  /// **'Supplementary Requests'**
  String get supplementaryRequests;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @createDistribution.
  ///
  /// In en, this message translates to:
  /// **'Create Distribution'**
  String get createDistribution;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @store.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get store;

  /// No description provided for @depot.
  ///
  /// In en, this message translates to:
  /// **'Depot'**
  String get depot;

  /// No description provided for @sourceStoreDepot.
  ///
  /// In en, this message translates to:
  /// **'Source (Store/Depot)'**
  String get sourceStoreDepot;

  /// No description provided for @selectLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Select the location with stock to distribute from'**
  String get selectLocationHint;

  /// No description provided for @materialRequestOptional.
  ///
  /// In en, this message translates to:
  /// **'Material Request (optional)'**
  String get materialRequestOptional;

  /// No description provided for @materialRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for auto-generated'**
  String get materialRequestHint;

  /// No description provided for @distributionDate.
  ///
  /// In en, this message translates to:
  /// **'Distribution date'**
  String get distributionDate;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @selectProjectFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a project first.'**
  String get selectProjectFirst;

  /// No description provided for @noProductsRequested.
  ///
  /// In en, this message translates to:
  /// **'No products requested by users for this project.'**
  String get noProductsRequested;

  /// No description provided for @pleaseSelectProjectStore.
  ///
  /// In en, this message translates to:
  /// **'Please select project, store, and add at least one product.'**
  String get pleaseSelectProjectStore;

  /// No description provided for @distributionCreated.
  ///
  /// In en, this message translates to:
  /// **'Distribution created. Material Request: {mr}'**
  String distributionCreated(String mr);

  /// No description provided for @noProductsAdded.
  ///
  /// In en, this message translates to:
  /// **'No products added. Tap Add to add products.'**
  String get noProductsAdded;

  /// No description provided for @selectProjectFirstShort.
  ///
  /// In en, this message translates to:
  /// **'Select project first'**
  String get selectProjectFirstShort;

  /// No description provided for @noProductsRequestedShort.
  ///
  /// In en, this message translates to:
  /// **'No products requested'**
  String get noProductsRequestedShort;

  /// No description provided for @pleaseEnterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Please enter a quantity greater than 0'**
  String get pleaseEnterQuantity;

  /// No description provided for @deleteDistribution.
  ///
  /// In en, this message translates to:
  /// **'Delete Distribution'**
  String get deleteDistribution;

  /// No description provided for @refuseDistribution.
  ///
  /// In en, this message translates to:
  /// **'Refuse Distribution'**
  String get refuseDistribution;

  /// No description provided for @validateDistribution.
  ///
  /// In en, this message translates to:
  /// **'Validate Distribution'**
  String get validateDistribution;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @validate.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get validate;

  /// No description provided for @refuse.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get refuse;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search {what}...'**
  String searchHint(String what);

  /// No description provided for @searchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get searchUsersHint;

  /// No description provided for @searchProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProductsHint;

  /// No description provided for @searchOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'Search orders...'**
  String get searchOrdersHint;

  /// No description provided for @searchProjectsHint.
  ///
  /// In en, this message translates to:
  /// **'Search projects...'**
  String get searchProjectsHint;

  /// No description provided for @searchStoresHint.
  ///
  /// In en, this message translates to:
  /// **'Search stores...'**
  String get searchStoresHint;

  /// No description provided for @searchDistributionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search distributions...'**
  String get searchDistributionsHint;

  /// No description provided for @noDistributionsMatch.
  ///
  /// In en, this message translates to:
  /// **'No distributions match your search.'**
  String get noDistributionsMatch;

  /// No description provided for @noDistributionsCreateHint.
  ///
  /// In en, this message translates to:
  /// **'No distributions yet. Create distributions via the API or add a form.'**
  String get noDistributionsCreateHint;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @distributionAccepted.
  ///
  /// In en, this message translates to:
  /// **'Distribution accepted. Material Request: {bon}'**
  String distributionAccepted(String bon);

  /// No description provided for @distributionRefused.
  ///
  /// In en, this message translates to:
  /// **'Distribution refused. Material Request: {bon}'**
  String distributionRefused(String bon);

  /// No description provided for @noDistributions.
  ///
  /// In en, this message translates to:
  /// **'No distributions yet.'**
  String get noDistributions;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get noOrders;

  /// No description provided for @noOrdersYetUser.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.\nYour orders will appear here.'**
  String get noOrdersYetUser;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet.'**
  String get noProjects;

  /// No description provided for @noStores.
  ///
  /// In en, this message translates to:
  /// **'No stores yet.'**
  String get noStores;

  /// No description provided for @noStoresMatch.
  ///
  /// In en, this message translates to:
  /// **'No stores match your search.'**
  String get noStoresMatch;

  /// No description provided for @noStoresTapAdd.
  ///
  /// In en, this message translates to:
  /// **'No stores yet. Tap + to add one.'**
  String get noStoresTapAdd;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products yet.'**
  String get noProducts;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYet;

  /// No description provided for @tapToAddFirstProduct.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first product'**
  String get tapToAddFirstProduct;

  /// No description provided for @noProductsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No products match your search'**
  String get noProductsMatchSearch;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryDifferentSearch;

  /// No description provided for @noUsers.
  ///
  /// In en, this message translates to:
  /// **'No users yet.'**
  String get noUsers;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This action cannot be undone.'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String confirmDeleteItem(String name);

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get deleteUser;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @deleteProject.
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get deleteProject;

  /// No description provided for @confirmDeleteProject.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? Users assigned to this project will be unassigned. This action cannot be undone.'**
  String confirmDeleteProject(String name);

  /// No description provided for @deleteOrder.
  ///
  /// In en, this message translates to:
  /// **'Delete Order'**
  String get deleteOrder;

  /// No description provided for @display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// No description provided for @approveOrder.
  ///
  /// In en, this message translates to:
  /// **'Approve Order'**
  String get approveOrder;

  /// No description provided for @approveSupplementaryRequest.
  ///
  /// In en, this message translates to:
  /// **'Approve supplementary request'**
  String get approveSupplementaryRequest;

  /// No description provided for @refuseSupplementaryRequest.
  ///
  /// In en, this message translates to:
  /// **'Refuse supplementary request'**
  String get refuseSupplementaryRequest;

  /// No description provided for @refuseSupplementaryRequestQuestion.
  ///
  /// In en, this message translates to:
  /// **'Refuse this supplementary request?'**
  String get refuseSupplementaryRequestQuestion;

  /// No description provided for @selectStoreToDeduct.
  ///
  /// In en, this message translates to:
  /// **'Select store to deduct stock from:'**
  String get selectStoreToDeduct;

  /// No description provided for @stockDeductedFromStore.
  ///
  /// In en, this message translates to:
  /// **'Stock will be deducted from this store.'**
  String get stockDeductedFromStore;

  /// No description provided for @orderApproved.
  ///
  /// In en, this message translates to:
  /// **'Order approved. Stock deducted.'**
  String get orderApproved;

  /// No description provided for @orderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Order deleted.'**
  String get orderDeleted;

  /// No description provided for @rejectOrder.
  ///
  /// In en, this message translates to:
  /// **'Reject Order'**
  String get rejectOrder;

  /// No description provided for @rejectOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reject this order? The project quota will be restored.'**
  String get rejectOrderQuestion;

  /// No description provided for @orderRejected.
  ///
  /// In en, this message translates to:
  /// **'Order rejected. Project quota restored.'**
  String get orderRejected;

  /// No description provided for @supplementaryRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Supplementary request approved'**
  String get supplementaryRequestApproved;

  /// No description provided for @supplementaryRequestRefused.
  ///
  /// In en, this message translates to:
  /// **'Supplementary request refused'**
  String get supplementaryRequestRefused;

  /// No description provided for @noSupplementaryRequests.
  ///
  /// In en, this message translates to:
  /// **'No supplementary requests'**
  String get noSupplementaryRequests;

  /// No description provided for @noStoresAvailable.
  ///
  /// In en, this message translates to:
  /// **'No stores available'**
  String get noStoresAvailable;

  /// No description provided for @productsLabel.
  ///
  /// In en, this message translates to:
  /// **'Products:'**
  String get productsLabel;

  /// No description provided for @productsAdditional.
  ///
  /// In en, this message translates to:
  /// **'Products (additional quantities):'**
  String get productsAdditional;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User:'**
  String get user;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatusPending;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get orderStatusRejected;

  /// No description provided for @orderQtyLabelProject.
  ///
  /// In en, this message translates to:
  /// **'(project)'**
  String get orderQtyLabelProject;

  /// No description provided for @orderQtyLabelSupplementary.
  ///
  /// In en, this message translates to:
  /// **'(supplementary)'**
  String get orderQtyLabelSupplementary;

  /// No description provided for @orderDate.
  ///
  /// In en, this message translates to:
  /// **'Order date:'**
  String get orderDate;

  /// No description provided for @orderDateValue.
  ///
  /// In en, this message translates to:
  /// **'Order date: {date}'**
  String orderDateValue(String date);

  /// No description provided for @projectLabel.
  ///
  /// In en, this message translates to:
  /// **'Project: {name}'**
  String projectLabel(String name);

  /// No description provided for @userLabel.
  ///
  /// In en, this message translates to:
  /// **'User: {name}'**
  String userLabel(String name);

  /// No description provided for @approvedQuantities.
  ///
  /// In en, this message translates to:
  /// **'Approved quantities (by admin):'**
  String get approvedQuantities;

  /// No description provided for @noProductsLabel.
  ///
  /// In en, this message translates to:
  /// **'No products'**
  String get noProductsLabel;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get newOrder;

  /// No description provided for @addProductSmall.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProductSmall;

  /// No description provided for @allProductsAdded.
  ///
  /// In en, this message translates to:
  /// **'All products have been added.'**
  String get allProductsAdded;

  /// No description provided for @addAtLeastOneProduct.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product with quantity > 0'**
  String get addAtLeastOneProduct;

  /// No description provided for @orderPlacedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order placed successfully'**
  String get orderPlacedSuccess;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @supplementary.
  ///
  /// In en, this message translates to:
  /// **'Supplementary'**
  String get supplementary;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String notesLabel(String notes);

  /// No description provided for @noOrdersMatch.
  ///
  /// In en, this message translates to:
  /// **'No orders match your search.'**
  String get noOrdersMatch;

  /// No description provided for @noProjectsMatch.
  ///
  /// In en, this message translates to:
  /// **'No projects match your search.'**
  String get noProjectsMatch;

  /// No description provided for @noProjectsTapAdd.
  ///
  /// In en, this message translates to:
  /// **'No projects yet. Tap + to add one.'**
  String get noProjectsTapAdd;

  /// No description provided for @addDamagedProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Damaged Product'**
  String get addDamagedProduct;

  /// No description provided for @allProductsAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'All products are already added.'**
  String get allProductsAlreadyAdded;

  /// No description provided for @addProductsStoresFirst.
  ///
  /// In en, this message translates to:
  /// **'Add products, stores, and projects first.'**
  String get addProductsStoresFirst;

  /// No description provided for @variantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Variants ({unit})'**
  String variantsLabel(String unit);

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editItem(String name);

  /// No description provided for @maxQty.
  ///
  /// In en, this message translates to:
  /// **'Max qty:'**
  String get maxQty;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @addVariants.
  ///
  /// In en, this message translates to:
  /// **'Add Variants'**
  String get addVariants;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @addOtherVariant.
  ///
  /// In en, this message translates to:
  /// **'Add other variant'**
  String get addOtherVariant;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory;

  /// No description provided for @browseImage.
  ///
  /// In en, this message translates to:
  /// **'Browse image from computer'**
  String get browseImage;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProduct;

  /// No description provided for @nameArOptional.
  ///
  /// In en, this message translates to:
  /// **'Arabic name (optional)'**
  String get nameArOptional;

  /// No description provided for @productImageSection.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get productImageSection;

  /// No description provided for @unitRequired.
  ///
  /// In en, this message translates to:
  /// **'Unit *'**
  String get unitRequired;

  /// No description provided for @unitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. piece, kg, m²'**
  String get unitHint;

  /// No description provided for @categoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get categoryRequired;

  /// No description provided for @productVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get productVariantsTitle;

  /// No description provided for @selectCategoryFirstForVariants.
  ///
  /// In en, this message translates to:
  /// **'Select a category above to add variants'**
  String get selectCategoryFirstForVariants;

  /// No description provided for @variantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Variant name'**
  String get variantNameLabel;

  /// No description provided for @variantNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Custom 100'**
  String get variantNameHint;

  /// No description provided for @addVariantsDescription.
  ///
  /// In en, this message translates to:
  /// **'Select from predefined list or add custom'**
  String get addVariantsDescription;

  /// No description provided for @tapToSelectImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to select image'**
  String get tapToSelectImage;

  /// No description provided for @productCategoryRetainingWall.
  ///
  /// In en, this message translates to:
  /// **'Retaining Wall System'**
  String get productCategoryRetainingWall;

  /// No description provided for @productCategoryGeocell.
  ///
  /// In en, this message translates to:
  /// **'Geocell'**
  String get productCategoryGeocell;

  /// No description provided for @productCategoryGeogrid.
  ///
  /// In en, this message translates to:
  /// **'Geogrid'**
  String get productCategoryGeogrid;

  /// No description provided for @productCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get productCategoryOther;

  /// No description provided for @roleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get roleUser;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse User'**
  String get roleWarehouse;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'-- None --'**
  String get none;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @usersAssigned.
  ///
  /// In en, this message translates to:
  /// **'Users assigned'**
  String get usersAssigned;

  /// No description provided for @deleteOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete order'**
  String get deleteOrderLabel;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @refused.
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get refused;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason *'**
  String get reasonRequired;

  /// No description provided for @damagedProductAdded.
  ///
  /// In en, this message translates to:
  /// **'Damaged product added'**
  String get damagedProductAdded;

  /// No description provided for @noDamagedProducts.
  ///
  /// In en, this message translates to:
  /// **'No damaged products yet'**
  String get noDamagedProducts;

  /// No description provided for @distributionDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Distribution date:'**
  String get distributionDateLabel;

  /// No description provided for @createdDate.
  ///
  /// In en, this message translates to:
  /// **'Created date:'**
  String get createdDate;

  /// No description provided for @validatedDate.
  ///
  /// In en, this message translates to:
  /// **'Validated date:'**
  String get validatedDate;

  /// No description provided for @approvedDate.
  ///
  /// In en, this message translates to:
  /// **'Approved date:'**
  String get approvedDate;

  /// No description provided for @materialRequest.
  ///
  /// In en, this message translates to:
  /// **'Material Request:'**
  String get materialRequest;

  /// No description provided for @creationDate.
  ///
  /// In en, this message translates to:
  /// **'Creation date:'**
  String get creationDate;

  /// No description provided for @productCreationDate.
  ///
  /// In en, this message translates to:
  /// **'Product creation date:'**
  String get productCreationDate;

  /// No description provided for @returnDateByUser.
  ///
  /// In en, this message translates to:
  /// **'Return date by user:'**
  String get returnDateByUser;

  /// No description provided for @cannotDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete this item'**
  String get cannotDeleteItem;

  /// No description provided for @deleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteQuestion;

  /// No description provided for @deleteItemQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this {type}?'**
  String deleteItemQuestion(String type);

  /// No description provided for @deletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get deletedSuccess;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @availableColors.
  ///
  /// In en, this message translates to:
  /// **'Available variants'**
  String get availableColors;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @manufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacture'**
  String get manufacturer;

  /// No description provided for @distributor.
  ///
  /// In en, this message translates to:
  /// **'Distributor'**
  String get distributor;

  /// No description provided for @storesDepots.
  ///
  /// In en, this message translates to:
  /// **'Stores / Depots'**
  String get storesDepots;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @projectsManagement.
  ///
  /// In en, this message translates to:
  /// **'Projects Management'**
  String get projectsManagement;

  /// No description provided for @usersManagement.
  ///
  /// In en, this message translates to:
  /// **'Users Management'**
  String get usersManagement;

  /// No description provided for @noUsersTapAdd.
  ///
  /// In en, this message translates to:
  /// **'No users yet. Tap + to add one.'**
  String get noUsersTapAdd;

  /// No description provided for @noUsersMatch.
  ///
  /// In en, this message translates to:
  /// **'No users match your search.'**
  String get noUsersMatch;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @confirmDeleteDistribution.
  ///
  /// In en, this message translates to:
  /// **'Delete distribution \"{name}\"? This action cannot be undone.'**
  String confirmDeleteDistribution(String name);

  /// No description provided for @refuseDistributionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Refuse distribution \"{name}\"? This will not deduct any stock.'**
  String refuseDistributionQuestion(String name);

  /// No description provided for @validateDistributionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Validate distribution \"{name}\"? This will deduct stock from the store.'**
  String validateDistributionQuestion(String name);

  /// No description provided for @orderApprovedCreateDist.
  ///
  /// In en, this message translates to:
  /// **'Order approved – Create distribution'**
  String get orderApprovedCreateDist;

  /// No description provided for @distributionDateValue.
  ///
  /// In en, this message translates to:
  /// **'Distribution date: {date}'**
  String distributionDateValue(String date);

  /// No description provided for @approveReturn.
  ///
  /// In en, this message translates to:
  /// **'Approve Return'**
  String get approveReturn;

  /// No description provided for @approveDamagedProduct.
  ///
  /// In en, this message translates to:
  /// **'Approve Damaged Product'**
  String get approveDamagedProduct;

  /// No description provided for @approveDamagedProductQuestion.
  ///
  /// In en, this message translates to:
  /// **'Approve \"{name}\" (qty: {qty})? This will deduct stock from the store.'**
  String approveDamagedProductQuestion(String name, int qty);

  /// No description provided for @totalGlobalStock.
  ///
  /// In en, this message translates to:
  /// **'Total Global Stock'**
  String get totalGlobalStock;

  /// No description provided for @deleteStore.
  ///
  /// In en, this message translates to:
  /// **'Delete Store'**
  String get deleteStore;

  /// No description provided for @addQuantityFor.
  ///
  /// In en, this message translates to:
  /// **'Add quantity - {name}'**
  String addQuantityFor(String name);

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'Add Stock'**
  String get addStock;

  /// No description provided for @editStock.
  ///
  /// In en, this message translates to:
  /// **'Edit Stock'**
  String get editStock;

  /// No description provided for @editStockSelectedVariant.
  ///
  /// In en, this message translates to:
  /// **'Selected variant'**
  String get editStockSelectedVariant;

  /// No description provided for @deleteStock.
  ///
  /// In en, this message translates to:
  /// **'Delete Stock'**
  String get deleteStock;

  /// No description provided for @updateQuantity.
  ///
  /// In en, this message translates to:
  /// **'Update Quantity'**
  String get updateQuantity;

  /// No description provided for @addProductToReturn.
  ///
  /// In en, this message translates to:
  /// **'Add product to return'**
  String get addProductToReturn;

  /// No description provided for @newReturn.
  ///
  /// In en, this message translates to:
  /// **'New Return'**
  String get newReturn;

  /// No description provided for @pleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get pleaseSelectCategory;

  /// No description provided for @imageUploadFailedSaving.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed. Saving with {type} image.'**
  String imageUploadFailedSaving(String type);

  /// No description provided for @qtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty:'**
  String get qtyLabel;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @distributed.
  ///
  /// In en, this message translates to:
  /// **'Distributed'**
  String get distributed;

  /// No description provided for @stockRecordDeleted.
  ///
  /// In en, this message translates to:
  /// **'Stock record deleted'**
  String get stockRecordDeleted;

  /// No description provided for @noStockMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No stock records match your search.'**
  String get noStockMatchSearch;

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed. Saving with {type} image.'**
  String imageUploadFailed(String type);

  /// No description provided for @stockDetails.
  ///
  /// In en, this message translates to:
  /// **'Stock Details'**
  String get stockDetails;

  /// No description provided for @deleteStockRecordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete stock record for \"{product}\" at {store}? Quantity: {qty}. This action cannot be undone.'**
  String deleteStockRecordQuestion(String product, String store, String qty);

  /// No description provided for @noStockYet.
  ///
  /// In en, this message translates to:
  /// **'No stock records yet.'**
  String get noStockYet;

  /// No description provided for @tapToAddStock.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add stock for a product in a store.'**
  String get tapToAddStock;

  /// No description provided for @stockManagement.
  ///
  /// In en, this message translates to:
  /// **'Stock Management'**
  String get stockManagement;

  /// No description provided for @stockDistinctProductsCount.
  ///
  /// In en, this message translates to:
  /// **'Products in stock: {count}'**
  String stockDistinctProductsCount(int count);

  /// No description provided for @stockSearchMatchCount.
  ///
  /// In en, this message translates to:
  /// **'Matches: {count}'**
  String stockSearchMatchCount(int count);

  /// No description provided for @searchStockHint.
  ///
  /// In en, this message translates to:
  /// **'Search stock...'**
  String get searchStockHint;

  /// No description provided for @storesManagement.
  ///
  /// In en, this message translates to:
  /// **'Stores Management'**
  String get storesManagement;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationOnMaps.
  ///
  /// In en, this message translates to:
  /// **'Location on maps'**
  String get locationOnMaps;

  /// No description provided for @locationMapsHint.
  ///
  /// In en, this message translates to:
  /// **'Address, coordinates, or paste a Google Maps link'**
  String get locationMapsHint;

  /// No description provided for @enterLocationForMaps.
  ///
  /// In en, this message translates to:
  /// **'Enter a location first'**
  String get enterLocationForMaps;

  /// No description provided for @mapsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps. Check the link or try again.'**
  String get mapsOpenFailed;

  /// No description provided for @deleteOrderRestoreStock.
  ///
  /// In en, this message translates to:
  /// **'Delete this order? Stock will be restored to the store.'**
  String get deleteOrderRestoreStock;

  /// No description provided for @deleteOrderSimple.
  ///
  /// In en, this message translates to:
  /// **'Delete this order?'**
  String get deleteOrderSimple;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @addProductsAndStoresFirst.
  ///
  /// In en, this message translates to:
  /// **'Add products and stores first.'**
  String get addProductsAndStoresFirst;

  /// No description provided for @variant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get variant;

  /// No description provided for @variantOrColor.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get variantOrColor;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get color;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get addProject;

  /// No description provided for @editProject.
  ///
  /// In en, this message translates to:
  /// **'Edit Project'**
  String get editProject;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameRequired;

  /// No description provided for @nameEnglishRequired.
  ///
  /// In en, this message translates to:
  /// **'Name (English) *'**
  String get nameEnglishRequired;

  /// No description provided for @projectOwner.
  ///
  /// In en, this message translates to:
  /// **'Project Owner'**
  String get projectOwner;

  /// No description provided for @projectOwnerArabic.
  ///
  /// In en, this message translates to:
  /// **'Project Owner (Arabic)'**
  String get projectOwnerArabic;

  /// No description provided for @projectBoqDate.
  ///
  /// In en, this message translates to:
  /// **'B.O.Q date'**
  String get projectBoqDate;

  /// No description provided for @projectBoqCreationDateRequired.
  ///
  /// In en, this message translates to:
  /// **'B.O.Q creation date *'**
  String get projectBoqCreationDateRequired;

  /// No description provided for @projectLastEditDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Last project update'**
  String get projectLastEditDateLabel;

  /// No description provided for @productsQuantitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Products (quantities users can order)'**
  String get productsQuantitiesHint;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @maxQuantityUsersCanOrder.
  ///
  /// In en, this message translates to:
  /// **'Max quantity (users can order)'**
  String get maxQuantityUsersCanOrder;

  /// No description provided for @selectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select product...'**
  String get selectProduct;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @addStore.
  ///
  /// In en, this message translates to:
  /// **'Add Store'**
  String get addStore;

  /// No description provided for @editStore.
  ///
  /// In en, this message translates to:
  /// **'Edit Store'**
  String get editStore;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Management'**
  String get appTitle;

  /// No description provided for @noItemsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No items match your search.'**
  String get noItemsMatchSearch;

  /// No description provided for @materialRequestLabel.
  ///
  /// In en, this message translates to:
  /// **'Material Request:'**
  String get materialRequestLabel;

  /// No description provided for @andMore.
  ///
  /// In en, this message translates to:
  /// **'... and more'**
  String get andMore;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @selectProductsQuantities.
  ///
  /// In en, this message translates to:
  /// **'Select products and quantities'**
  String get selectProductsQuantities;

  /// No description provided for @noProductsAvailableForProject.
  ///
  /// In en, this message translates to:
  /// **'No products available for your project'**
  String get noProductsAvailableForProject;

  /// No description provided for @contactAdminAddProducts.
  ///
  /// In en, this message translates to:
  /// **'Contact your admin to add products to your project'**
  String get contactAdminAddProducts;

  /// No description provided for @quantityAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Quantity added successfully'**
  String get quantityAddedSuccess;

  /// No description provided for @couldNotLoadProduct.
  ///
  /// In en, this message translates to:
  /// **'Could not load product'**
  String get couldNotLoadProduct;

  /// No description provided for @viewProduct.
  ///
  /// In en, this message translates to:
  /// **'View product'**
  String get viewProduct;

  /// No description provided for @selectStoreUndamagedProducts.
  ///
  /// In en, this message translates to:
  /// **'Select store where undamaged products will be added:'**
  String get selectStoreUndamagedProducts;

  /// No description provided for @goodStoreOriginDamagedSelected.
  ///
  /// In en, this message translates to:
  /// **'Good → store of origin | Damaged → selected store'**
  String get goodStoreOriginDamagedSelected;

  /// No description provided for @returnApprovedUndamagedAdded.
  ///
  /// In en, this message translates to:
  /// **'Return approved. Undamaged products added to warehouse.'**
  String get returnApprovedUndamagedAdded;

  /// No description provided for @approveAddUndamagedWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Approve (add undamaged to warehouse)'**
  String get approveAddUndamagedWarehouse;

  /// No description provided for @returnsFromUsersAppear.
  ///
  /// In en, this message translates to:
  /// **'Returns from users will appear here.'**
  String get returnsFromUsersAppear;

  /// No description provided for @noReturnsYet.
  ///
  /// In en, this message translates to:
  /// **'No returns yet.'**
  String get noReturnsYet;

  /// No description provided for @returnSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Return submitted successfully'**
  String get returnSubmittedSuccess;

  /// No description provided for @submitReturn.
  ///
  /// In en, this message translates to:
  /// **'Submit Return'**
  String get submitReturn;

  /// No description provided for @myReturns.
  ///
  /// In en, this message translates to:
  /// **'My Returns'**
  String get myReturns;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity:'**
  String get quantityLabel;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason:'**
  String get reasonLabel;

  /// No description provided for @storeLabel.
  ///
  /// In en, this message translates to:
  /// **'Store:'**
  String get storeLabel;

  /// No description provided for @notesLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Notes:'**
  String get notesLabelShort;

  /// No description provided for @goodCondition.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get goodCondition;

  /// No description provided for @damagedCondition.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get damagedCondition;

  /// No description provided for @noStoresAddFirst.
  ///
  /// In en, this message translates to:
  /// **'No stores available. Add stores first.'**
  String get noStoresAddFirst;

  /// No description provided for @goodConditionReturnOrigin.
  ///
  /// In en, this message translates to:
  /// **'Good condition products return to their store of origin (from product config).'**
  String get goodConditionReturnOrigin;

  /// No description provided for @selectStoreDamagedFallback.
  ///
  /// In en, this message translates to:
  /// **'Select store for damaged products and as fallback if product has no store:'**
  String get selectStoreDamagedFallback;

  /// No description provided for @supplementaryRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplementary requests'**
  String get supplementaryRequestsTitle;

  /// No description provided for @damagedProduct.
  ///
  /// In en, this message translates to:
  /// **'Damaged product'**
  String get damagedProduct;

  /// No description provided for @stockChange.
  ///
  /// In en, this message translates to:
  /// **'Stock change'**
  String get stockChange;

  /// No description provided for @reportDateByUser.
  ///
  /// In en, this message translates to:
  /// **'Report date by user:'**
  String get reportDateByUser;

  /// No description provided for @orderDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Order date *'**
  String get orderDateRequired;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No {type} found.'**
  String noItemsFound(String type);

  /// No description provided for @quantityToAdd.
  ///
  /// In en, this message translates to:
  /// **'Quantity to add'**
  String get quantityToAdd;

  /// No description provided for @storeRequired.
  ///
  /// In en, this message translates to:
  /// **'Store *'**
  String get storeRequired;

  /// No description provided for @validationRequiredByAdmin.
  ///
  /// In en, this message translates to:
  /// **'Validation required by Admin only'**
  String get validationRequiredByAdmin;

  /// No description provided for @selectProductsToReturn.
  ///
  /// In en, this message translates to:
  /// **'Select products and quantities to return'**
  String get selectProductsToReturn;

  /// No description provided for @conditionLabel.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get conditionLabel;

  /// No description provided for @userRequestedAdditionalQuantities.
  ///
  /// In en, this message translates to:
  /// **'{name} requested additional quantities'**
  String userRequestedAdditionalQuantities(String name);

  /// No description provided for @searchReturnsHint.
  ///
  /// In en, this message translates to:
  /// **'Search returns...'**
  String get searchReturnsHint;

  /// No description provided for @noReturnsMatch.
  ///
  /// In en, this message translates to:
  /// **'No returns match your search.'**
  String get noReturnsMatch;

  /// No description provided for @requestLabel.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get requestLabel;

  /// No description provided for @userFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallback;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get addUser;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get editUser;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @projectOptional.
  ///
  /// In en, this message translates to:
  /// **'Project (optional)'**
  String get projectOptional;

  /// No description provided for @minimum6Characters.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get minimum6Characters;

  /// No description provided for @maxQtyFormatted.
  ///
  /// In en, this message translates to:
  /// **'Max: {max} {unit}'**
  String maxQtyFormatted(String max, String unit);

  /// No description provided for @notAssignedToProject.
  ///
  /// In en, this message translates to:
  /// **'You are not assigned to any project. Contact your admin.'**
  String get notAssignedToProject;

  /// No description provided for @approvedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Approved by: {name}'**
  String approvedByLabel(String name);

  /// No description provided for @createdByLabel.
  ///
  /// In en, this message translates to:
  /// **'Created by: {name}'**
  String createdByLabel(String name);

  /// No description provided for @validatedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Validated by: {name}'**
  String validatedByLabel(String name);

  /// No description provided for @statusWithValue.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusWithValue(String status);

  /// No description provided for @returnWithProject.
  ///
  /// In en, this message translates to:
  /// **'Return • {project}'**
  String returnWithProject(String project);

  /// No description provided for @returnItem.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnItem;

  /// No description provided for @searchDamagedHint.
  ///
  /// In en, this message translates to:
  /// **'Search damaged...'**
  String get searchDamagedHint;

  /// No description provided for @noDamagedProductsReportedYet.
  ///
  /// In en, this message translates to:
  /// **'No damaged products reported yet'**
  String get noDamagedProductsReportedYet;

  /// No description provided for @yourDamagedReportsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your reports will appear here'**
  String get yourDamagedReportsWillAppear;

  /// No description provided for @extraQuantityPart.
  ///
  /// In en, this message translates to:
  /// **'(extra: +{qty})'**
  String extraQuantityPart(String qty);

  /// No description provided for @noApprovedOrdersToDistribute.
  ///
  /// In en, this message translates to:
  /// **'No approved orders to distribute'**
  String get noApprovedOrdersToDistribute;

  /// No description provided for @whenAdminApprovesOrderHint.
  ///
  /// In en, this message translates to:
  /// **'When admin approves an order, it will appear here with quantities.\nUse + to create a distribution manually.'**
  String get whenAdminApprovesOrderHint;

  /// No description provided for @orderNumberPrefix.
  ///
  /// In en, this message translates to:
  /// **'Order #{prefix}...'**
  String orderNumberPrefix(String prefix);

  /// No description provided for @orderCardProductsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} products • {total} total'**
  String orderCardProductsSummary(int count, int total);

  /// No description provided for @productsRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Products *'**
  String get productsRequiredLabel;

  /// No description provided for @qtyWithOptionalColor.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}{suffix}'**
  String qtyWithOptionalColor(String qty, String suffix);

  /// No description provided for @imageUploadFailedSavingExisting.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed. Saving with existing image.'**
  String get imageUploadFailedSavingExisting;

  /// No description provided for @imageUploadFailedSavingNo.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed. Saving without image.'**
  String get imageUploadFailedSavingNo;

  /// No description provided for @returnsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your returns will appear here.\nTap + to create a new return.'**
  String get returnsEmptySubtitle;

  /// No description provided for @administratorDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get administratorDisplayName;

  /// No description provided for @validatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get validatedStatus;

  /// No description provided for @qtyReasonStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty} • {reason} • {status}'**
  String qtyReasonStatusLine(String qty, String reason, String status);

  /// No description provided for @reportRowItem.
  ///
  /// In en, this message translates to:
  /// **'Item {n}'**
  String reportRowItem(int n);

  /// No description provided for @reportFieldCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get reportFieldCreatedAt;

  /// No description provided for @reportFieldUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated at'**
  String get reportFieldUpdatedAt;

  /// No description provided for @reportFieldApprovedAt.
  ///
  /// In en, this message translates to:
  /// **'Approved at'**
  String get reportFieldApprovedAt;

  /// No description provided for @reportFieldApprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Approved by'**
  String get reportFieldApprovedBy;

  /// No description provided for @reportFieldReportedBy.
  ///
  /// In en, this message translates to:
  /// **'Reported by'**
  String get reportFieldReportedBy;

  /// No description provided for @reportFieldProductId.
  ///
  /// In en, this message translates to:
  /// **'Product ID'**
  String get reportFieldProductId;

  /// No description provided for @reportFieldProjectId.
  ///
  /// In en, this message translates to:
  /// **'Project ID'**
  String get reportFieldProjectId;

  /// No description provided for @reportFieldStoreId.
  ///
  /// In en, this message translates to:
  /// **'Store ID'**
  String get reportFieldStoreId;

  /// No description provided for @reportFieldUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get reportFieldUserId;

  /// No description provided for @reportFieldDeliveryDate.
  ///
  /// In en, this message translates to:
  /// **'Delivery date'**
  String get reportFieldDeliveryDate;

  /// No description provided for @reportFieldSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get reportFieldSerialNumber;

  /// No description provided for @reportFieldBonAlimentation.
  ///
  /// In en, this message translates to:
  /// **'Material request ref.'**
  String get reportFieldBonAlimentation;

  /// No description provided for @reportFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get reportFieldType;

  /// No description provided for @reportFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get reportFieldPhone;

  /// No description provided for @reportFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get reportFieldAddress;

  /// No description provided for @reportFieldImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get reportFieldImage;

  /// No description provided for @reportFieldRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get reportFieldRole;

  /// No description provided for @reportFieldProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get reportFieldProduct;

  /// No description provided for @reportFieldColor.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get reportFieldColor;

  /// No description provided for @reportFieldCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get reportFieldCondition;

  /// No description provided for @reportFieldExtraQuantity.
  ///
  /// In en, this message translates to:
  /// **'Extra quantity'**
  String get reportFieldExtraQuantity;

  /// No description provided for @reportFieldOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get reportFieldOrderId;

  /// No description provided for @reportFieldReturnId.
  ///
  /// In en, this message translates to:
  /// **'Return ID'**
  String get reportFieldReturnId;

  /// No description provided for @reportFieldDistributionId.
  ///
  /// In en, this message translates to:
  /// **'Distribution ID'**
  String get reportFieldDistributionId;

  /// No description provided for @reportFieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get reportFieldQuantity;

  /// No description provided for @reportFieldTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportFieldTotal;

  /// No description provided for @reportFieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get reportFieldPrice;

  /// No description provided for @reportFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get reportFieldAmount;

  /// No description provided for @reportFieldDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get reportFieldDetails;

  /// No description provided for @reportFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reportFieldTitle;

  /// No description provided for @reportFieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get reportFieldCode;

  /// No description provided for @reportFieldReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reportFieldReference;

  /// No description provided for @reportFieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get reportFieldLocation;

  /// No description provided for @reportFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportFieldDate;

  /// No description provided for @reportFieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reportFieldTime;

  /// No description provided for @reportFieldComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get reportFieldComment;

  /// No description provided for @reportFieldPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get reportFieldPriority;

  /// No description provided for @reportFieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get reportFieldSource;

  /// No description provided for @reportFieldDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get reportFieldDestination;

  /// No description provided for @reportFieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get reportFieldValue;

  /// No description provided for @reportFieldKey.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get reportFieldKey;

  /// No description provided for @reportFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get reportFieldNotes;

  /// No description provided for @reportFieldUnknown.
  ///
  /// In en, this message translates to:
  /// **'{key}'**
  String reportFieldUnknown(String key);

  /// No description provided for @distributionSingle.
  ///
  /// In en, this message translates to:
  /// **'Distribution'**
  String get distributionSingle;

  /// No description provided for @removeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTooltip;

  /// No description provided for @qtyShort.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qtyShort;

  /// No description provided for @allocatedWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Allocated: {allocated} {unit}'**
  String allocatedWithUnit(String allocated, String unit);

  /// No description provided for @allocatedDropdownSuffix.
  ///
  /// In en, this message translates to:
  /// **' (allocated: {n})'**
  String allocatedDropdownSuffix(String n);

  /// No description provided for @supplementaryRequestMoreHint.
  ///
  /// In en, this message translates to:
  /// **'You can request more (supplementary, requires admin approval)'**
  String get supplementaryRequestMoreHint;

  /// No description provided for @orderQuantitySupplementaryHint.
  ///
  /// In en, this message translates to:
  /// **'Min: 1, e.g. {example} for supplementary'**
  String orderQuantitySupplementaryHint(String example);

  /// No description provided for @allocatedSummaryWithExtra.
  ///
  /// In en, this message translates to:
  /// **'Allocated: {allocated} {unit} • +{extra} extra'**
  String allocatedSummaryWithExtra(String allocated, String unit, String extra);

  /// No description provided for @productNameWithMaxQty.
  ///
  /// In en, this message translates to:
  /// **'{name} (max: {max})'**
  String productNameWithMaxQty(String name, String max);

  /// No description provided for @maxQtyHintNumber.
  ///
  /// In en, this message translates to:
  /// **'Max: {max}'**
  String maxQtyHintNumber(String max);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
