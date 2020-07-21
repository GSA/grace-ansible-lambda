# Make coding more python3-ish, this is required for contributions to Ansible
from __future__ import absolute_import, division, print_function

import json
from pprint import pformat

__metaclass__ = type

# not only visible to ansible-doc, it also 'declares' the options the plugin requires and how to configure them.
DOCUMENTATION = """
  callback: aws-events
  callback_type: default
  requirements:
    - whitelist in configuration
  short_description: logs aws events
  version_added: "2.0"
  description:
      - logs aws events
"""
from datetime import datetime

from ansible.plugins.callback import CallbackBase
# import boto3

# cloudwatch_events = boto3.client("events")

class CallbackModule(CallbackBase):
    """
        self.runner_on_unredef v2_playbook_on_start(self, playbook):
    This callback module sends aws events for each ansible callback.
    """

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "stdout"
    CALLBACK_NAME = "default"

    # only needed if you ship it and don't want to enable by default
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):

        # make sure the expected objects are present, calling the base's __init__
        super(CallbackModule, self).__init__()

        # start the timer when the plugin is loaded, the first play should start a few milliseconds after.
        self.start_time = datetime.now()

    def put_event(self, type, data):
        # Create CloudWatchEvents client
        # cloudwatch_events = boto3.client("events")
        #
        # # Put an event
        # response = cloudwatch_events.put_events(
        #     Entries=[
        #         {
        #             "Detail": data,
        #             "DetailType": type,
        #             "Resources": [
        #                 # TODO resource ARN?
        #                 "RESOURCE_ARN",
        #             ],
        #             "Source": "gov.gsa.ansible",
        #         }
        #     ]
        # )
        print(type)
        print(data)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self.put_event("runnerFailed", {"host": result._host.get_name(), "dump": pformat(vars(result))})

    def v2_runner_on_ok(self, result):
        self.put_event("runnerOkay", {"host": result._host.get_name(), "dump": pformat(vars(result))})

    def v2_runner_on_skipped(self, result):
        self.put_event("runnerSkipped", {"host": result._host.get_name(), "dump": pformat(vars(result))})

    def v2_runner_on_unreachable(self, result):
        self.put_event("runnerUnreachable", {"host": result._host.get_name(), "dump": pformat(vars(result))})

    def v2_playbook_on_notify(self, handler, host):
        self.put_event("playbookNotify", {"host": host.get_name(), "dump": pformat(vars(handler))})

    def v2_playbook_on_no_hosts_matched(self):
        self.put_event("noHostsMatched", {})

    def v2_playbook_on_no_hosts_remaining(self):
        self.put_event("noHostsRemaining", {})

    def v2_playbook_on_task_start(self, task, is_conditional):
        self.put_event("taskStart", {"task": task, "dump": pformat(vars(task))})
