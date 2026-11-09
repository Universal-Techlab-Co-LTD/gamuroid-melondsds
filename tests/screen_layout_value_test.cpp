// Host unit test for the gamuroid_screen_layout parser.
// Build and run: scripts/run_host_tests.sh
#include "gamuroid/screen_layout_value.hpp"

#include <cstdio>
#include <string>

using namespace MelonDsDs::gamuroid;

static int failures = 0;

#define CHECK(cond) do { if (!(cond)) { std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); failures++; } } while (0)

static ParsedScreenLayoutValue P(const char* s) { return ParseScreenLayoutValue(s); }
static bool IsInvalid(const char* s) { return P(s).kind == ScreenLayoutValueKind::Invalid; }
static bool IsCustom(const char* s) { return P(s).kind == ScreenLayoutValueKind::Custom; }

int main() {
    // Automatic
    CHECK(P("").kind == ScreenLayoutValueKind::Automatic);
    CHECK(P("auto").kind == ScreenLayoutValueKind::Automatic);

    // Valid, documented example
    {
        auto r = P("L1;canvas=1179x2556;upper=0,180,1179,884;lower=0,1110,1179,884;rev=3");
        CHECK(r.kind == ScreenLayoutValueKind::Custom);
        CHECK(r.layout.canvasWidth == 1179 && r.layout.canvasHeight == 2556);
        CHECK(r.layout.upper.x == 0 && r.layout.upper.y == 180 && r.layout.upper.w == 1179 && r.layout.upper.h == 884);
        CHECK(r.layout.lower.y == 1110);
        CHECK(r.layout.revision == 3);
    }
    // Any order, rev optional, trailing ';' ignored
    CHECK(IsCustom("L1;lower=0,0,256,192;upper=none;canvas=256x192"));
    CHECK(P("L1;lower=0,0,256,192;upper=none;canvas=256x192").layout.revision == 0);
    CHECK(IsCustom("L1;canvas=256x384;upper=0,0,256,192;lower=0,192,256,192;"));
    // Unknown field ignored
    CHECK(IsCustom("L1;canvas=256x384;upper=0,0,256,192;lower=0,192,256,192;future=1,2"));
    // none and zero size
    {
        auto r = P("L1;canvas=10x10;upper=none;lower=5,5,0,3");
        CHECK(r.kind == ScreenLayoutValueKind::Custom);
        CHECK(!r.layout.upper.Visible());
        CHECK(!r.layout.lower.Visible());
        CHECK(r.layout.lower == ScreenBox {});
    }
    // Bounds
    CHECK(IsCustom("L1;canvas=8192x8192;upper=16384,16384,16384,16384;lower=0,0,0,0"));
    CHECK(IsCustom("L1;canvas=1x1;upper=0,0,1,1;lower=none"));
    CHECK(IsInvalid("L1;canvas=8193x10;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=0x10;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=16385,0,1,1;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=0,0,1,16385;lower=none"));
    CHECK(P("L1;canvas=10x10;upper=none;lower=none;rev=4294967295").layout.revision == 4294967295u);
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none;rev=4294967296"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none;rev=99999999999999999999999"));
    // rev change is a different layout
    CHECK(P("L1;canvas=10x10;upper=none;lower=none;rev=1").layout != P("L1;canvas=10x10;upper=none;lower=none;rev=2").layout);
    // Missing and duplicate fields
    CHECK(IsInvalid("L1;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none"));
    CHECK(IsInvalid("L1;canvas=10x10;canvas=10x10;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none;rev=1;rev=1"));
    // Malformed numbers
    CHECK(IsInvalid("L1;canvas=10x10;upper=0,0,1;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=0,0,1,1,1;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=-1,0,1,1;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=0.5,0,1,1;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=,0,1,1;lower=none"));
    CHECK(IsInvalid("L1;canvas=10;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=nonee;lower=none"));
    // Version
    CHECK(IsInvalid("L2;canvas=10x10;upper=none;lower=none"));
    CHECK(IsInvalid("canvas=10x10;upper=none;lower=none"));
    CHECK(IsInvalid(";L1;canvas=10x10;upper=none;lower=none"));
    // Characters
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none\n"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none\r"));
    CHECK(IsInvalid("L1; canvas=10x10;upper=none;lower=none"));
    CHECK(IsInvalid("L1;CANVAS=10x10;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none;rev=\xC3\xA9"));
    CHECK(IsInvalid("L1;;canvas=10x10;upper=none;lower=none"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none;;"));
    CHECK(IsInvalid("L1;canvas=10x10;upper=none;lower=none;novalue"));
    CHECK(IsInvalid("auto;"));

    if (failures == 0) {
        std::printf("screen_layout_value_test: all checks passed\n");
        return 0;
    }
    std::printf("screen_layout_value_test: %d failure(s)\n", failures);
    return 1;
}
