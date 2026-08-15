import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/data/storage/preferences_manager.dart';
import 'package:fly_narwhal/ui/features/player/services/player_device_context_service.dart';

void main() {
  group('PlayerDeviceContextService', () {
    test(
      'Given valid hardware serial, When loading device context, Then it prefers the hardware serial and system name',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerDeviceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async {
            final script = arguments.last;
            if (script.contains('Win32_BIOS')) {
              return ProcessResult(0, 0, 'PF2FL9KE', '');
            }
            if (script.contains('Win32_ComputerSystem).Name')) {
              return ProcessResult(0, 0, 'JANKINWU_PC', '');
            }
            return ProcessResult(0, 0, '', '');
          },
        );

        // When
        final context = await service.loadContext();

        // Then
        expect(context.deviceId, equals('PF2FL9KE'));
        expect(context.deviceName, equals('JANKINWU_PC'));
      },
    );

    test(
      'Given invalid primary identifiers, When loading device context, Then it falls back to the next valid hardware identifier',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerDeviceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async {
            final script = arguments.last;
            if (script.contains('Win32_BIOS')) {
              return ProcessResult(0, 0, 'To Be Filled By O.E.M.', '');
            }
            if (script.contains('Win32_ComputerSystemProduct).UUID')) {
              return ProcessResult(
                0,
                0,
                '820C0BC8-459C-11EB-80EA-8C8CAA67E7AD',
                '',
              );
            }
            if (script.contains('Win32_ComputerSystem).Name')) {
              return ProcessResult(0, 0, 'JANKINWU_PC', '');
            }
            return ProcessResult(0, 0, '', '');
          },
        );

        // When
        final context = await service.loadContext();

        // Then
        expect(
          context.deviceId,
          equals('820C0BC8-459C-11EB-80EA-8C8CAA67E7AD'),
        );
      },
    );

    test(
      'Given all hardware identifiers fail, When loading device context twice, Then it persists and reuses a generated fallback id',
      () async {
        // Given
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = PlayerDeviceContextService(
          PreferencesManager(prefs),
          processRunner: (executable, arguments) async {
            final script = arguments.last;
            if (script.contains('Win32_ComputerSystem).Name')) {
              return ProcessResult(0, 0, '', '');
            }
            if (script.contains('Win32_ComputerSystem).DNSHostName')) {
              return ProcessResult(0, 0, '', '');
            }
            return ProcessResult(
                0, 0, '00000000-0000-0000-0000-000000000000', '');
          },
        );

        // When
        final firstContext = await service.loadContext();
        final secondContext = await service.loadContext();

        // Then
        expect(firstContext.deviceId, startsWith('jvm_'));
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
