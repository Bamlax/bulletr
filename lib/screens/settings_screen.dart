import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/dev_logs.dart';

// 1. 设置主菜单
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("设置"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text("关于 bulletr"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code, color: Colors.purple),
            title: const Text("开发者 Bamlax"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperScreen()));
            },
          ),
        ],
      ),
    );
  }
}

// 2. 关于页面 (查看开发日志)
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("关于 bulletr")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appDevLogs.length,
        itemBuilder: (context, index) {
          final log = appDevLogs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "v${log.version}", 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)
                      ),
                      Text(log.date, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(),
                  ...log.changes.map((change) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(change)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 3. 开发者页面 (跳转链接)
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  // 跳转 URL 的通用方法
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  // 发送邮件的方法
  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'bamlax@example.com', // 替换成你的真实邮箱
      query: 'subject=关于bulletr的反馈',
    );
    if (!await launchUrl(emailLaunchUri)) {
      throw Exception('Could not launch email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("开发者")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.purple,
              child: Text("B", style: TextStyle(fontSize: 40, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            const Text("Bamlax", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("独立开发者", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            
            // GitHub 按钮
            ListTile(
              leading: const Icon(Icons.link, size: 30),
              title: const Text("GitHub"),
              subtitle: const Text("github.com/bamlax"), // 替换你的 GitHub 地址
              onTap: () => _launchUrl("https://github.com/bamlax"), 
            ),
            
            const Divider(indent: 20, endIndent: 20),

            // Email 按钮
            ListTile(
              leading: const Icon(Icons.email_outlined, size: 30),
              title: const Text("Email"),
              subtitle: const Text("发送反馈邮件"),
              onTap: _sendEmail,
            ),
          ],
        ),
      ),
    );
  }
}