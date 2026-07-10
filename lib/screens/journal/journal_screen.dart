import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/journal_service.dart';
import '../../services/settings_service.dart';
import '../../utils/app_route.dart';
import 'journal_detail_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _RagJournalEmptyState extends StatelessWidget {
  const _RagJournalEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 80,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            "No Journal Entries Yet",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Buddy logs insights, conversation history, and preferences locally to help assist you. Start chatting with Buddy to create your first journal entry!",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _JournalScreenState extends State<JournalScreen> {
  final _journalService = JournalService();
  List<Map<String, dynamic>> _journals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  Future<void> _loadJournals() async {
    setState(() => _isLoading = true);
    final list = await _journalService.getJournalsList();
    if (mounted) {
      setState(() {
        _journals = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final isDark = AppColors.primaryBackground == Colors.black;

        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          appBar: AppBar(
            backgroundColor: AppColors.primaryBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primaryText),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              "Buddy's Journal",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: AppColors.primaryText),
                onPressed: _loadJournals,
              ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryButton,
                  ),
                )
              : _journals.isEmpty
                  ? const Center(child: _RagJournalEmptyState())
                  : SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Explanatory card
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 10.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.cardBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.psychology,
                                    size: 40,
                                    color: isDark ? Colors.tealAccent : const Color(0xFF00796B),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      "Buddy learns from your actions, conversations, and preferences, saving them offline as Markdown files to serve as local knowledge.",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 12.0,
                            ),
                            child: Text(
                              "Daily Entries",
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.extrabold,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _journals.length,
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              itemBuilder: (context, index) {
                                final journal = _journals[index];
                                final dateStr = journal['date'] as String;
                                final filePath = journal['path'] as String;
                                final name = journal['name'] as String;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.lightBackground,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.unselectedBorder,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20.0,
                                        vertical: 8.0,
                                      ),
                                      leading: const CircleAvatar(
                                        backgroundColor: Color(0xFF0F766E),
                                        child: Icon(
                                          Icons.article,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        "Journal - $dateStr",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.chevron_right,
                                        color: AppColors.primaryText,
                                      ),
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          AppRoute.to(JournalDetailScreen(
                                            filePath: filePath,
                                            dateStr: dateStr,
                                          )),
                                        );
                                        _loadJournals(); // reload on return in case of changes
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}
