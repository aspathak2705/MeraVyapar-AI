import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import 'locale_provider.dart';

class LanguageSelectorButton extends ConsumerWidget {
  const LanguageSelectorButton({super.key});

  String _getBadgeLabel(String code) {
    switch (code) {
      case 'hi':
        return 'हिंदी';
      case 'mr':
        return 'मराठी';
      case 'en':
      default:
        return 'EN';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      tooltip: 'Select Language / भाषा निवडा / भाषा चुनें',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: PopupMenuPosition.under,
      onSelected: (String code) async {
        await ref.read(localeProvider.notifier).setLanguageCode(code);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkPrimaryPurple.withValues(alpha: 0.2)
                : AppColors.lightLavender,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppColors.darkPrimaryPurple.withValues(alpha: 0.4)
                  : AppColors.primaryPurple.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.translate_rounded,
                size: 15,
                color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
              ),
              const SizedBox(width: 4),
              Text(
                _getBadgeLabel(currentLocale.languageCode),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (BuildContext context) {
        return kSupportedLanguages.map((AppLanguage lang) {
          final isSelected = lang.code == currentLocale.languageCode;
          return PopupMenuItem<String>(
            value: lang.code,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected
                      ? AppColors.primaryPurple
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primaryPurple
                              : (isDark ? Colors.white : AppColors.lightTextPrimary),
                        ),
                      ),
                      if (lang.code != 'en')
                        Text(
                          lang.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
