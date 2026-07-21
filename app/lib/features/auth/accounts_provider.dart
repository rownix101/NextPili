import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/core_api.dart';

class AccountsNotifier extends Notifier<List<AccountPublicDto>> {
  @override
  List<AccountPublicDto> build() {
    try {
      return CoreApi.instance.listAccounts();
    } catch (_) {
      return const [];
    }
  }

  void refresh() {
    state = CoreApi.instance.listAccounts();
  }
}

final accountsProvider =
    NotifierProvider<AccountsNotifier, List<AccountPublicDto>>(
  AccountsNotifier.new,
);
