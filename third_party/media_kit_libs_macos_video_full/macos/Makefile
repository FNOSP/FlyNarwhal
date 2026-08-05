all: Frameworks/*.xcframework Frameworks/.symlinks

# Vendored local override of media_kit_libs_macos_video.
# Downloads the *full* FFmpeg/mpv XCFramework from media-kit/libmpv-darwin-build
# (PGS/HDMV SUP bitmap subtitle support) and verifies the archive SHA-256
# before extraction.
#
# Pinned to v0.7.2 instead of the v0.6.0 used by upstream 1.1.4: v0.7.2
# rebuilds mpv to fix the `m_config_cache_from_shadow` (group_index >= 0)
# assertion that aborts the player during `mpv_render_context_create`
# (media-kit/media-kit#830, also reproduced on this project's default build).

MPV_XCFRAMEWORKS_VERSION=v0.7.2
# SHA-256 of libmpv-xcframeworks_v0.7.2_macos-universal-video-full.tar.gz.
# Computed locally on 2026-08-05 against
# https://github.com/media-kit/libmpv-darwin-build/releases/download/v0.7.2/libmpv-xcframeworks_v0.7.2_macos-universal-video-full.tar.gz
# and re-checked on every build. Update both this file and the verification
# script together when bumping the upstream release.
MPV_XCFRAMEWORKS_FULL_SHA256SUM=2e5a38eac99e0fcf8355fe33263832aafc67af85f4df26f343d61ece19478072

.cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal-full.tar.gz:
	mkdir -p .cache/xcframeworks
	rm -f .cache/xcframeworks/*.tmp .cache/xcframeworks/*-macos-universal-full.tar.gz
	curl -fL \
		https://github.com/media-kit/libmpv-darwin-build/releases/download/${MPV_XCFRAMEWORKS_VERSION}/libmpv-xcframeworks_${MPV_XCFRAMEWORKS_VERSION}_macos-universal-video-full.tar.gz \
		-o .cache/xcframeworks/libmpv.tar.gz.tmp
	shasum -a 256 -c <<< '${MPV_XCFRAMEWORKS_FULL_SHA256SUM}  .cache/xcframeworks/libmpv.tar.gz.tmp'
	mv .cache/xcframeworks/libmpv.tar.gz.tmp .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal-full.tar.gz
	touch .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal-full.tar.gz

.cache/xcframeworks/libmpv-xcframeworks-macos-universal-full.tar.gz: .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal-full.tar.gz
	rm -f .cache/xcframeworks/libmpv-xcframeworks-macos-universal-full.tar.gz
	ln -s libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal-full.tar.gz .cache/xcframeworks/libmpv-xcframeworks-macos-universal-full.tar.gz

Frameworks/*.xcframework: .cache/xcframeworks/libmpv-xcframeworks-macos-universal-full.tar.gz
	mkdir -p Frameworks
	rm -rf Frameworks/*.xcframework
	tar -xvf .cache/xcframeworks/libmpv-xcframeworks-macos-universal-full.tar.gz --strip-components 1 -C Frameworks
	touch Frameworks/*.xcframework

Frameworks/.symlinks: Frameworks/*.xcframework
	rm -rf Frameworks/.symlinks
	mkdir -p Frameworks/.symlinks/mpv
	sed -i '' 's/\r$$//g' create_framework_symlinks.sh # remove CRLF line terminator added by Flutter packaging (https://github.com/media-kit/media-kit/issues/338)
	sh create_framework_symlinks.sh Frameworks/Mpv.xcframework Frameworks/.symlinks/mpv

.PHONY: clean
clean:
	rm -rf .cache
	rm -f ./Headers/mpv/*.h
	rm -rf ./Frameworks/*.xcframework
