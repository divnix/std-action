const core = require("@actions/core");

async function run() {
  try {
    process.kill(process.env.STATE_SSH_AGENT_PID);
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
