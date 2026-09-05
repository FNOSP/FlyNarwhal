import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/data/storage/preferences_manager.dart';
import 'package:fly_narwhal/ui/features/player/services/player_device_context_service.dart';

void main() {
  group('PlayerDeviceContextService', () {
    test(
      'Given a KMP-migrated fallback device id, When loading device context, Then it reuses the migrated id',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({
          'fallback_device_id': 'jvm_123e4567-e89b-12d3-a456-426614174000',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerDeviceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async =>
              ProcessResult(0, 0, '', ''),
        );

        // When
        final context = await service.loadContext();

        // Then
        expect(
          context.deviceId,
          equals('jvm_123e4567-e89b-12d3-a456-426614174000'),
        );
        expect(context.deviceIdType, equals('persisted_uuid'));
      },
    );

    test(
      'Given no persisted device id, When loading device context twice, Then it persists and reuses a generated fallback id',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerDeviceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async =>
              ProcessResult(0, 0, '', ''),
        );

        // When
        final firstContext = await service.loadContext();
        final secondContext = await service.loadContext();

        // Then
        expect(firstContext.deviceId, startsWith('flutter_'));
        expect(firstContext.deviceIdType, equals('generated_uuid'));
        expect(secondContext.deviceId, equals(firstContext.deviceId));
        expect(
          prefs.getString('fallback_device_id'),
          equals(firstContext.deviceId),
        );
        expect(secondContext.deviceName, isNotEmpty);
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
