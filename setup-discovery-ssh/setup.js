import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import * as core from "@actions/core";
import * as exec from "@actions/exec";

async function run() {
  try {
    core.exportVariable("DISCOVERY_USER_NAME", core.getInput("user_name"));
    core.exportVariable(
      "DISCOVERY_SSH_KNOWN_HOSTS_ENTRY",
      core.getInput("ssh_known_hosts_entry")
    );
    core.exportVariable("DISCOVERY_SSH_KEY", core.getInput("ssh_key"));
    // await exec.exec(path.resolve(__dirname, "setup.sh"), []);
    await exec.exec(path.resolve(__dirname, "setup.sh"));
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
