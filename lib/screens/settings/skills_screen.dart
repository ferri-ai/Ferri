import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/ferri_engine.dart';
import '../../providers/engine_provider.dart';
import '../../providers/skills_provider.dart';
import '../../theme/colors.dart';

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  @override
  void initState() {
    super.initState();
    // Load skills when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(skillsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final skillsState = ref.watch(skillsProvider);
    final engineStatus = ref.watch(engineProvider);

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: FerriColors.text, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Skills',
                          style: TextStyle(
                            color: FerriColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      'Skills extend what Ferri can do. They teach the AI '
                      'specialized workflows using your device capabilities.',
                      style: TextStyle(
                        color: FerriColors.textSoft,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Engine not ready warning
            if (engineStatus != EngineStatus.ready)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Engine not running. Start a chat first to load skills.',
                    style: TextStyle(color: FerriColors.warning, fontSize: 13),
                  ),
                ),
              ),

            // Loading indicator
            if (skillsState.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: FerriColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),

            // Skills list
            if (!skillsState.loading && skillsState.skills.isNotEmpty) ...[
              _buildSectionHeader(
                  '${skillsState.skills.length} SKILLS LOADED'),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final skill = skillsState.skills[index];
                    return _SkillTile(
                      skill: skill,
                      onTap: () => _showSkillDetail(skill),
                    );
                  },
                  childCount: skillsState.skills.length,
                ),
              ),
            ],

            // Empty state
            if (!skillsState.loading && skillsState.skills.isEmpty &&
                engineStatus == EngineStatus.ready)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No skills found. Ask Ferri to create one!',
                      style:
                          TextStyle(color: FerriColors.textFaint, fontSize: 14),
                    ),
                  ),
                ),
              ),

            // Actions section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ADD SKILLS',
                      style: TextStyle(
                        color: FerriColors.textFaint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      icon: Icons.auto_awesome,
                      iconColor: FerriColors.primary,
                      title: 'Create in Chat',
                      description:
                          'Ask Ferri: "Create a skill that helps me..."',
                      onTap: () {
                        // Copy prompt to clipboard as a shortcut
                        Clipboard.setData(const ClipboardData(
                            text: 'Create a new skill that helps me '));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Prompt copied! Paste it in the chat.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      icon: Icons.download,
                      iconColor: FerriColors.textFaint,
                      title: 'Import from GitHub',
                      description: 'Coming soon',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            // Info note
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Text(
                  'Skills are SKILL.md files stored in your workspace. '
                  'The AI reads them on demand to learn specialized workflows. '
                  'No code execution \u2014 skills are pure instructions.',
                  style: TextStyle(
                    color: FerriColors.textFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: FerriColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FerriColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: FerriColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text(description,
                      style: const TextStyle(
                          color: FerriColors.textFaint,
                          fontSize: 12,
                          height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: FerriColors.textFaint, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSkillDetail(SkillInfo skill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FerriColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: FerriColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      skill.name,
                      style: const TextStyle(
                        color: FerriColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: FerriColors.primaryDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      skill.source,
                      style: const TextStyle(
                          color: FerriColors.primary, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                skill.description.isNotEmpty
                    ? skill.description
                    : 'No description',
                style: const TextStyle(
                  color: FerriColors.textSoft,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                skill.path,
                style: const TextStyle(
                  color: FerriColors.textFaint,
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(height: 16),
              // Uninstall button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _confirmUninstall(ctx, skill),
                  child: const Text(
                    'Uninstall Skill',
                    style: TextStyle(color: FerriColors.danger),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmUninstall(BuildContext ctx, SkillInfo skill) {
    Navigator.pop(ctx); // Close bottom sheet
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FerriColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Uninstall Skill',
            style: TextStyle(color: FerriColors.text)),
        content: Text(
          'Remove "${skill.name}"? This deletes the SKILL.md file.',
          style: const TextStyle(color: FerriColors.textSoft, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: FerriColors.textFaint)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await ref
                  .read(skillsProvider.notifier)
                  .uninstall(skill.name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? '${skill.name} uninstalled'
                      : 'Failed to uninstall'),
                ));
              }
            },
            child: const Text('Uninstall',
                style: TextStyle(color: FerriColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showInstallDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FerriColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Install from GitHub',
            style: TextStyle(color: FerriColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the GitHub repository (e.g. user/skill-name):',
              style: TextStyle(color: FerriColors.textSoft, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: FerriColors.text),
              decoration: InputDecoration(
                hintText: 'user/skill-name',
                hintStyle: const TextStyle(color: FerriColors.textFaint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FerriColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: FerriColors.borderFocus),
                ),
                filled: true,
                fillColor: FerriColors.bgInput,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: FerriColors.textFaint)),
          ),
          TextButton(
            onPressed: () async {
              final repo = controller.text.trim();
              Navigator.pop(ctx);
              if (repo.isEmpty) return;
              final success =
                  await ref.read(skillsProvider.notifier).install(repo);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      success ? 'Skill installed!' : 'Failed to install'),
                ));
              }
            },
            child: const Text('Install',
                style: TextStyle(color: FerriColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final SkillInfo skill;
  final VoidCallback onTap;

  const _SkillTile({required this.skill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: FerriColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FerriColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 18, color: FerriColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(
                        color: FerriColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (skill.description.isNotEmpty)
                      Text(
                        skill.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FerriColors.textFaint,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FerriColors.primaryDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  skill.source,
                  style: const TextStyle(
                      color: FerriColors.primary, fontSize: 10),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: FerriColors.textFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
