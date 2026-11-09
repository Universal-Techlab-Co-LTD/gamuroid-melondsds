// Host unit test for the gamuroid_net_state_* protocol.
// Build and run: scripts/run_host_tests.sh
#include "gamuroid/net_state.hpp"

#include <cstdio>
#include <vector>

using namespace MelonDsDs::gamuroid;

static int failures = 0;
static std::vector<int> calls;

#define CHECK(cond) do { if (!(cond)) { std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); failures++; } } while (0)

static void Listener(int code) { calls.push_back(code); }

int main() {
    // Before any session: 0, nothing reported
    CHECK(gamuroid_net_state_get() == 0);
    gamuroid_net_state_listen(Listener);
    CHECK(!NetStateUpdate(2));
    CHECK(calls.empty());

    // Session 1: once per change, never when unchanged
    NetStateSessionBegin();
    CHECK(gamuroid_net_state_get() == 0);
    CHECK(!NetStateUpdate(0));
    CHECK(NetStateUpdate(1));
    CHECK(!NetStateUpdate(1));
    CHECK(NetStateUpdate(2));
    CHECK(!NetStateUpdate(2));
    CHECK(gamuroid_net_state_get() == 2);
    CHECK((calls == std::vector<int>{1, 2}));

    // Out-of-range codes count as 0
    CHECK(NetStateUpdate(7));
    CHECK(calls.back() == 0);
    CHECK(NetStateUpdate(2));

    // Unload while online: one report of 0, then quiet
    calls.clear();
    NetStateSessionEnd();
    CHECK((calls == std::vector<int>{0}));
    CHECK(gamuroid_net_state_get() == 0);
    CHECK(!NetStateUpdate(2));
    CHECK((calls == std::vector<int>{0}));

    // Unload while offline: no report
    NetStateSessionBegin();
    calls.clear();
    NetStateSessionEnd();
    CHECK(calls.empty());

    // Next session starts offline even if the previous one did not unload
    NetStateSessionBegin();
    CHECK(NetStateUpdate(2));
    NetStateSessionBegin();
    CHECK(gamuroid_net_state_get() == 0);

    // Null listener stops calls
    calls.clear();
    gamuroid_net_state_listen(nullptr);
    CHECK(NetStateUpdate(1));
    CHECK(calls.empty());
    gamuroid_net_state_listen(Listener);

    // After deinit the listener is forgotten
    NetStateForget();
    NetStateSessionBegin();
    CHECK(NetStateUpdate(2));
    CHECK(calls.empty());
    CHECK(gamuroid_net_state_get() == 2);
    NetStateSessionEnd();
    CHECK(calls.empty());

    if (failures == 0) {
        std::printf("net_state_test: all checks passed\n");
        return 0;
    }
    std::printf("net_state_test: %d failure(s)\n", failures);
    return 1;
}
