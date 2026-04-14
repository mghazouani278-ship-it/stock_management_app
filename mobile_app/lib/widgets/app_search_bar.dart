import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Reusable search bar for list screens - title or search field
class AppSearchBar extends StatelessWidget {
  final String title;
  final String searchHint;
  final TextEditingController searchController;
  final bool showSearch;
  /// Optional count to display in title (e.g. "Orders (15)")
  final int? count;

  const AppSearchBar({
    super.key,
    required this.title,
    required this.searchHint,
    required this.searchController,
    required this.showSearch,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return showSearch
        ? SizedBox(
            height: 36,
            child: TextField(
              controller: searchController,
              autofocus: true,
              style: AppTheme.appTextStyle(context, fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: AppTheme.appTextStyle(context, fontSize: 14, color: AppTheme.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          )
        : Text(
            count != null ? '$title ($count)' : title,
            style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600),
          );
  }

  /// Search button (small) - use in AppBar actions
  static Widget searchButton({
    required BuildContext context,
    required bool showSearch,
    required VoidCallback onToggleSearch,
  }) {
    return IconButton(
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
      ),
      iconSize: 20,
      icon: showSearch
          ? const Icon(Icons.close_rounded, size: 20)
          : SizedBox(
              width: 20,
              height: 20,
              child: SvgPicture.asset(
                'assets/images/search.svg',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).iconTheme.color ?? AppTheme.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
      onPressed: onToggleSearch,
    );
  }
}
