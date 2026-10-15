package com.william.treino;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/** Native result transport avoids the CLI VM-service discovery race in CI. */
@RunWith(FlutterTestRunner.class)
public class WorkoutIntegrationTest {
    @Rule public ActivityTestRule<MainActivity> rule =
        new ActivityTestRule<>(MainActivity.class, true, false);
}
