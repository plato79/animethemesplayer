import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/anime_providers.dart';

class AnimeSearchBar extends ConsumerStatefulWidget {
  const AnimeSearchBar({super.key});

  @override
  ConsumerState<AnimeSearchBar> createState() => _AnimeSearchBarState();
}

class _AnimeSearchBarState extends ConsumerState<AnimeSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Set searching state
    setState(() {
      _isSearching = true;
    });

    // Cancel previous timer if it exists
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    // Create a new timer to delay the search
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Update search query in provider
      ref.read(searchQueryProvider.notifier).state = query;

      // End searching state
      setState(() {
        _isSearching = false;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search anime (e.g., "Naruto", "One Piece")',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearching)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                    ],
                  )
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceVariant.withOpacity(0.3),
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }
}
