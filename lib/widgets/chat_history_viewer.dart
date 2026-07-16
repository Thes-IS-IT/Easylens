import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/journal_service.dart';
import '../services/settings_service.dart';

class ChatHistoryViewer {
  static void showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = SettingsService().selectedContrastTheme;
            final isDefault = theme == 'Default';

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: AppColors.unselectedBorder, width: 1.5),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: JournalService().getJournalsList(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final journals = snapshot.data ?? [];
                  if (journals.isEmpty) {
                    return Center(
                      child: Text(
                        "No memory history found yet.",
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Buddy's Chat Memory",
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: AppColors.primaryText),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: journals.length,
                          itemBuilder: (context, idx) {
                            final j = journals[idx];
                            final date = j['date'] as String;
                            final file = j['file'] as File;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 0,
                              color: isDefault ? const Color(0xFFF1F5F9) : AppColors.lightBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: AppColors.unselectedBorder.withOpacity(0.5)),
                              ),
                              child: ExpansionTile(
                                leading: Icon(Icons.calendar_today, color: AppColors.primaryButton),
                                title: Text(
                                  date,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                children: [
                                  FutureBuilder<String>(
                                    future: JournalService().readJournalContent(file.path),
                                    builder: (context, contentSnapshot) {
                                      if (contentSnapshot.connectionState == ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      final rawText = contentSnapshot.data ?? '';
                                      // Clean/Format the markdown log to be easily readable
                                      final cleanedText = rawText
                                          .replaceAll("# Buddy's Journal - $date", '')
                                          .replaceAll("## Buddy's Insights & Notes", "\n💡 Buddy's Insights:\n")
                                          .replaceAll("## Conversation Logs", "\n💬 Chat Logs:\n")
                                          .replaceAll("### Chat Log at", "🕐 Log at")
                                          .replaceAll("- **User**:", "👤 User:")
                                          .replaceAll("- **Buddy**:", "🐕 Buddy:")
                                          .trim();

                                      return Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            cleanedText.isEmpty ? "No chat history recorded for today." : cleanedText,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              height: 1.5,
                                              color: AppColors.primaryText,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
