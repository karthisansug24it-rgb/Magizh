import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final selected = locale == null
        ? null
        : appLanguages.firstWhere(
            (language) => language.code == locale.languageCode,
            orElse: () => appLanguages.first,
          );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(context.t('settings')),
        backgroundColor: AppTheme.scaffoldBg,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _HeaderCard(selected: selected),
            const SizedBox(height: 18),
            Text(
              context.t('regionalLanguages'),
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SystemLanguageTile(
                isSelected: locale == null,
                onTap: () => ref.read(localeProvider.notifier).setLocale(null),
              ),
            ),
            ...appLanguages.map((language) {
              final isSelected = language.code == locale?.languageCode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LanguageTile(
                  language: language,
                  isSelected: isSelected,
                  onTap: () => ref.read(localeProvider.notifier).setLocale(language.code),
                ),
              );
            }),
            const SizedBox(height: 8),
            _SystemCard(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppLanguage? selected;

  const _HeaderCard({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.translate_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('appLanguage'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t('languageSubtitle'),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${context.t('selectedLanguage')}: ${selected?.nativeName ?? context.t('systemDefaultNative')}",
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t('instantApply'),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : const Color(0xFFE5E2DD),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.scaffoldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  language.code.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.nativeName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${language.name} • ${language.region}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.verified_rounded, color: AppTheme.primary)
              else
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemLanguageTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _SystemLanguageTile({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : const Color(0xFFE5E2DD),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.scaffoldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  color: isSelected ? Colors.white : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('systemDefault'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${context.t('followDeviceLanguage')} • ${context.t('systemDefaultRegion')}",
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.verified_rounded, color: AppTheme.primary)
              else
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final AppLanguage? selected;

  const _SystemCard({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security_update_good_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('systemReady'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('systemReadySubtitle'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
