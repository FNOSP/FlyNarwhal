package lang

import "testing"

func TestDetectLanguageFromWindowsID(t *testing.T) {
	t.Parallel()

	if got, ok := detectLanguageFromWindowsID(0x0804); !ok || got != Zh {
		t.Fatalf("detectLanguageFromWindowsID(0x0804) = (%v, %v), want (%v, true)", got, ok, Zh)
	}
	if got, ok := detectLanguageFromWindowsID(0x0409); !ok || got != En {
		t.Fatalf("detectLanguageFromWindowsID(0x0409) = (%v, %v), want (%v, true)", got, ok, En)
	}
	if got, ok := detectLanguageFromWindowsID(0x0411); ok || got != En {
		t.Fatalf("detectLanguageFromWindowsID(0x0411) = (%v, %v), want (%v, false)", got, ok, En)
	}
}

func TestDetectLanguageFromEnvironment(t *testing.T) {
	t.Parallel()

	if got, ok := detectLanguageFromEnvironment("zh_CN.UTF-8"); !ok || got != Zh {
		t.Fatalf("detectLanguageFromEnvironment(zh_CN.UTF-8) = (%v, %v), want (%v, true)", got, ok, Zh)
	}
	if got, ok := detectLanguageFromEnvironment("en_US.UTF-8"); !ok || got != En {
		t.Fatalf("detectLanguageFromEnvironment(en_US.UTF-8) = (%v, %v), want (%v, true)", got, ok, En)
	}
	if got, ok := detectLanguageFromEnvironment(""); ok || got != En {
		t.Fatalf("detectLanguageFromEnvironment(empty) = (%v, %v), want (%v, false)", got, ok, En)
	}
}

func TestMsgAndFallback(t *testing.T) {
	previousLanguage := CurrentLanguage
	t.Cleanup(func() { CurrentLanguage = previousLanguage })

	CurrentLanguage = Zh
	if got := Msg("expected_exactly_two_arguments", 3); got != "需要且只能传入两个参数，实际为 3 个" {
		t.Fatalf("Msg(zh) = %q", got)
	}

	CurrentLanguage = En
	if got := Msg("missing_key"); got != "missing_key" {
		t.Fatalf("Msg fallback = %q", got)
	}
}
