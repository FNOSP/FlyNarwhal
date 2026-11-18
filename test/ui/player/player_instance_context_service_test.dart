import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/core/identity/instance_id.dart';
import 'package:fly_narwhal/data/storage/preferences_manager.dart';
import 'package:fly_narwhal/ui/features/player/services/player_instance_context_service.dart';

void main() {
  group('PlayerInstanceContextService', () {
    test(
      'Given a persisted instance id, When loading the instance context, Then it reuses the persisted id',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({
          'instance_id': 'macos-arm64-fn-3f9a2b7c14d8e6a0',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerInstanceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async =>
              ProcessResult(0, 0, '', ''),
        );

        // When
        final context = await service.loadContext();

        // Then
        expect(
          context.instanceId,
          equals('macos-arm64-fn-3f9a2b7c14d8e6a0'),
        );
        // No report id was ever stored for this profile: reporting falls back
        // to the instance id rather than inventing another one.
        expect(context.reportDeviceId, equals(context.instanceId));
      },
    );

    test(
      'Given only the old report device id, When loading the instance context, Then reporting keeps the old id',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({
          'report_device_id': 'jvm_123e4567-e89b-12d3-a456-426614174000',
          'instance_id': 'windows-x64-fn-0000000000000000',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerInstanceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async =>
              ProcessResult(0, 0, '', ''),
        );

        // When
        final context = await service.loadContext();

        // Then
        expect(
          context.reportDeviceId,
          equals('jvm_123e4567-e89b-12d3-a456-426614174000'),
        );
        expect(context.instanceId, equals('windows-x64-fn-0000000000000000'));
      },
    );

    test(
      'Given no persisted instance id, When loading the instance context twice, Then it persists and reuses a generated id',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerInstanceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async =>
              ProcessResult(0, 0, '', ''),
          random: Random(7),
        );

        // When
        final firstContext = await service.loadContext();
        final secondContext = await service.loadContext();

        // Then
        expect(
          firstContext.instanceId,
          matches(RegExp(r'^[a-z0-9]+-[a-z0-9]+-fn-[0-9a-f]{16}$')),
        );
        expect(secondContext.instanceId, equals(firstContext.instanceId));
        expect(
          prefs.getString('instance_id'),
          equals(firstContext.instanceId),
        );
        // Reporting keeps its own `<os>-<arch>-fly-<hex>` id and persists it.
        expect(
          firstContext.reportDeviceId,
          matches(RegExp(r'^[a-z0-9]+-[a-z0-9]+-fly-[0-9a-f]{16}$')),
        );
        expect(
          firstContext.reportDeviceId,
          isNot(equals(firstContext.instanceId)),
        );
        expect(
          prefs.getString('report_device_id'),
          equals(firstContext.reportDeviceId),
        );
        expect(secondContext.instanceName, isNotEmpty);
      },
    );
  });

  group('instance id format', () {
    test(
      'Given os and arch segments, When building an id, Then it reads as os-arch-fn-random',
      () {
        expect(
          buildInstanceId(
              os: 'macos', arch: 'arm64', randomHex: '0123456789abcdef'),
          equals('macos-arm64-fn-0123456789abcdef'),
        );
        expect(
          buildInstanceId(
              os: 'win', arch: 'x86_64', randomHex: 'aa'.padRight(16, '0')),
          equals('win-x8664-fn-aa00000000000000'),
        );
        expect(
          buildInstanceId(os: '', arch: '--', randomHex: '0'),
          equals('unknown-unknown-fn-0'),
        );
      },
    );

    test(
      'Given an old flutter_/jvm_ id, When converting it, Then it keeps the random part in the new format',
      () {
        expect(
          toInstanceIdFormat(
            'flutter_3f9a2b7c-14d8-e6a0-0000-000000000000',
            os: 'windows',
            arch: 'x64',
          ),
          equals('windows-x64-fn-3f9a2b7c14d8e6a00000000000000000'),
        );
        expect(
          toInstanceIdFormat('jvm_', os: 'linux', arch: 'arm64'),
          matches(RegExp(r'^linux-arm64-fn-[0-9a-f]{16}$')),
        );
      },
    );
  });

  group('resolveSupportedWindowsHwdecApis', () {
    test(
      'Given AMD adapter and only D3D11 runtime, When resolving Windows hwdec APIs, Then it only returns D3D11',
      () {
        // Given
        const adapters = [
          WindowsVideoAdapterInfo(
            name: 'AMD Radeon 780M Graphics',
            vendor: 'Advanced Micro Devices, Inc.',
            pnpDeviceId: 'PCI\\VEN_1002&DEV_15BF',
          ),
        ];

        // When
        final result = resolveSupportedWindowsHwdecApis(
          adapters: adapters,
          hasD3d11Runtime: true,
          hasCudaRuntime: false,
          hasNvdecRuntime: false,
        );

        // Then
        expect(result, equals(['d3d11va']));
      },
    );

    test(
      'Given NVIDIA adapter and all runtimes, When resolving Windows hwdec APIs, Then it returns D3D11 NVDEC and CUDA',
      () {
        // Given
        const adapters = [
          WindowsVideoAdapterInfo(
            name: 'NVIDIA GeForce RTX 4060 Laptop GPU',
            vendor: 'NVIDIA',
            pnpDeviceId: 'PCI\\VEN_10DE&DEV_28A0',
          ),
        ];

        // When
        final result = resolveSupportedWindowsHwdecApis(
          adapters: adapters,
          hasD3d11Runtime: true,
          hasCudaRuntime: true,
          hasNvdecRuntime: true,
        );

        // Then
        expect(result, equals(['d3d11va', 'nvdec', 'cuda']));
      },
    );
  });

  group('sanitizePlayerDecodeMode', () {
    test(
      'Given unsupported concrete hwdec mode, When sanitizing decode mode, Then it falls back to auto',
      () {
        // Given
        const supportedApis = ['d3d11va'];

        // When
        final result = sanitizePlayerDecodeMode('nvdec', supportedApis);

        // Then
        expect(result, equals('auto'));
      },
    );

    test(
      'Given base decode mode, When sanitizing decode mode, Then it keeps the original value',
      () {
        // Given
        const supportedApis = <String>[];

        // When
        final result = sanitizePlayerDecodeMode('no', supportedApis);

        // Then
        expect(result, equals('no'));
      },
    );
  });
}
