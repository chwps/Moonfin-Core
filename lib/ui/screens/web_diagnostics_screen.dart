import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../platform/web_runtime_config.dart';
import '../../util/platform_detection.dart';
import '../../util/server_url.dart';
import '../../util/web_diagnostics_failure.dart';
import '../navigation/destinations.dart';

class WebDiagnosticsScreen extends StatelessWidget {
  const WebDiagnosticsScreen({
    super.key,
    this.reason,
    this.targetUrl,
    this.detail,
  });

  final String? reason;
  final String? targetUrl;
  final String? detail;

  static const _corsSnippet =
      r'''# Example reverse-proxy headers for Moonfin web
add_header Access-Control-Allow-Origin "$http_origin" always;
add_header Access-Control-Allow-Credentials "true" always;
add_header Access-Control-Allow-Headers "Authorization, X-Emby-Authorization, X-Emby-Token, Content-Type, Range, Accept, Origin" always;
add_header Access-Control-Expose-Headers "Content-Length, Content-Range, Accept-Ranges" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
if ($request_method = OPTIONS) { return 204; }''';

  @override
  Widget build(BuildContext context) {
    final origin = Uri.base;
    final isHttpsPage = origin.scheme.toLowerCase() == 'https';
    final inferredReason = webDiagnosticsFailureReasonFromQuery(reason);
    final normalizedTargetUrl = _normalizeConfiguredUrl(targetUrl);
    final detailText = (detail ?? '').trim();

    final configuredTargets = <String>{
      _normalizeConfiguredUrl(webRuntimeConfig.forcedServerUrl),
      _normalizeConfiguredUrl(webRuntimeConfig.defaultServerUrl),
      _normalizeConfiguredUrl(webRuntimeConfig.discoveryProxyUrl),
    }.where((value) => value.isNotEmpty).toList(growable: false);

    final insecureConfiguredTargets = configuredTargets
        .where((url) => url.toLowerCase().startsWith('http://'))
        .toList(growable: false);

    final hasMixedContentRisk =
        PlatformDetection.isWeb &&
        isHttpsPage &&
        insecureConfiguredTargets.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Moonfin Web Diagnostics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Use this page to diagnose browser connectivity issues (CORS, mixed content, and discovery settings).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (inferredReason != null) ...[
              _StatusCard(
                title:
                    inferredReason == WebDiagnosticsFailureReason.mixedContent
                    ? 'Detected Mixed-Content Failure'
                    : 'Detected CORS/Preflight Failure',
                icon: Icons.error_outline,
                color: AppColorScheme.statusRequested.withValues(alpha: 0.22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (inferredReason ==
                        WebDiagnosticsFailureReason.mixedContent)
                      const Text(
                        'Moonfin detected an HTTPS page trying to call an HTTP server URL. Browsers block this request before it reaches your server.',
                      )
                    else
                      const Text(
                        'Moonfin detected a browser-level request failure that is commonly caused by missing CORS or preflight headers on the media server.',
                      ),
                    if (normalizedTargetUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Target URL: $normalizedTargetUrl'),
                    ],
                    if (detailText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Detail: $detailText'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _StatusCard(
              title: 'Current Runtime Context',
              icon: Icons.public,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Origin', origin.origin),
                  _kv('Scheme', origin.scheme),
                  _kv(
                    'Plugin Mode',
                    webRuntimeConfig.pluginMode ? 'enabled' : 'disabled',
                  ),
                  _kv(
                    'WebRTC Scan',
                    webRuntimeConfig.enableWebRtcScan ? 'enabled' : 'disabled',
                  ),
                  _kv(
                    'Forced Server URL',
                    webRuntimeConfig.forcedServerUrl?.trim().isNotEmpty == true
                        ? normalizeServerBaseUrl(
                            webRuntimeConfig.forcedServerUrl!.trim(),
                          )
                        : 'not configured',
                  ),
                  _kv(
                    'Default Server URL',
                    webRuntimeConfig.defaultServerUrl?.trim().isNotEmpty == true
                        ? normalizeServerBaseUrl(
                            webRuntimeConfig.defaultServerUrl!.trim(),
                          )
                        : 'not configured',
                  ),
                  _kv(
                    'Discovery Proxy URL',
                    webRuntimeConfig.discoveryProxyUrl?.trim().isNotEmpty ==
                            true
                        ? normalizeServerBaseUrl(
                            webRuntimeConfig.discoveryProxyUrl!.trim(),
                          )
                        : 'not configured',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Mixed Content',
              icon: hasMixedContentRisk
                  ? Icons.warning_amber
                  : Icons.check_circle,
              color: hasMixedContentRisk
                  ? AppColorScheme.statusRequested.withValues(alpha: 0.18)
                  : AppColorScheme.accent.withValues(alpha: 0.14),
              child: hasMixedContentRisk
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This page is loaded over HTTPS, but one or more configured URLs are HTTP. Browsers block HTTPS pages from calling HTTP APIs.',
                        ),
                        const SizedBox(height: 8),
                        ...insecureConfiguredTargets.map(
                          (url) => Text('• $url'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Fix: serve your media server or proxy endpoint via HTTPS, or load Moonfin over HTTP on trusted local networks only.',
                        ),
                      ],
                    )
                  : const Text(
                      'No obvious mixed-content configuration detected from current runtime settings.',
                    ),
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'CORS Checklist',
              icon: Icons.rule,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Allow the browser origin in Access-Control-Allow-Origin.',
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Include Authorization, X-Emby-Authorization, and X-Emby-Token in Access-Control-Allow-Headers.',
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Expose Content-Range and Accept-Ranges for streaming and seek behavior.',
                  ),
                  SizedBox(height: 4),
                  Text('• Return 204 to OPTIONS preflight requests.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Example Header Snippet (nginx-style)',
              icon: Icons.code,
              child: SelectableText(
                _corsSnippet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!PlatformDetection.isWeb)
              const _StatusCard(
                title: 'Note',
                icon: Icons.info,
                child: Text(
                  'This diagnostics route is intended for web builds. If you are seeing this on another platform, these checks may not apply.',
                ),
              ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(Destinations.serverSelect),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back To Server Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeConfiguredUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    return normalizeServerBaseUrl(trimmed);
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? color;

  const _StatusCard({
    required this.title,
    required this.icon,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color ?? AppColorScheme.onSurface.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColorScheme.onSurface.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
