# Make coding more python3-ish, this is required for contributions to Ansible
from __future__ import absolute_import, division, print_function

import sys
from pprint import pformat, pprint
from __main__ import cli

__metaclass__ = type

# not only visible to ansible-doc, it also 'declares' the options the plugin requires and how to configure them.
DOCUMENTATION = """
  callback: cloudwatch
  callback_type: notification 
  requirements:
    - whitelist in configuration
  short_description: logs aws events
  version_added: "2.0"
  description:
      - logs aws events
"""
from datetime import datetime

from ansible.plugins.callback import CallbackBase
import boto3
import os
import json
import uuid

cloudwatch_events = boto3.client("events")#, aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'], aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'])

run_id = str(uuid.uuid4())

STAT_OK      = 'ok'
STAT_FAILED  = 'failed'
STAT_SKIPPED = 'skipped'
STAT_CHANGED = 'changed'
STAT_UNREACHABLE = 'unreachable'

class HostReport():
    def __init__(self):
        self.run_id = run_id
        self.host = ""
        self.instance_id = ""
        self.unreachable = True
        self.stats = {
            STAT_OK: 0,
            STAT_CHANGED: 0,
            STAT_FAILED: 0,
            STAT_SKIPPED: 0,
        }
        self.tasks = []

    def inc_stat(self, stat, count):
        val = self.stats.get(stat, 0)
        self.stats[stat] = val + count

    def add_task(self, state, name, action, args):
        self.tasks.append({
            'state': state,
            'name': name,
            'action': action,
            'args': args,
        })
        
    def toJSON(self):
        return json.dumps(self.__dict__)

class CallbackModule(CallbackBase):
    """
        self.runner_on_unredef v2_playbook_on_start(self, playbook):
    This callback module sends aws events for each ansible callback.
    """

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'cloudwatch'

    # only needed if you ship it and don't want to enable by default
    # CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):

        # make sure the expected objects are present, calling the base's __init__
        super(CallbackModule, self).__init__()

        # start the timer when the plugin is loaded, the first play should start a few milliseconds after.
        self.start_time = datetime.now()

        self.reports = {}
        self.instances = {}

        self._query_instances()


    def put_event(self, type, data):
        if isinstance(data, HostReport):
            obj = data.toJSON()
        else:
            obj = json.dumps(data)

        response = cloudwatch_events.put_events(
            Entries=[
                {
                    # TODO: add instance ARNs
                    #"Resources": [
                    #    ,
                    #],
                    "Source": "ansible",
                    'DetailType': type,
                    'Detail': obj,
                }
            ]
        )

    def _pop_keys_by_prefix(self, d, prefix='_'):
        for k in list(d.keys()):
            if k.startswith(prefix):
                d.pop(k)
        return d

    def _query_instances(self):
        ec2 = boto3.resource('ec2')
        instances = ec2.instances.filter(Filters=[
            {
                'Name': 'instance-state-name',
                'Values': ['running']
            }
        ])
        for instance in instances:
            name = ''
            for t in instance.tags:
                if t.get('Key', '') == 'Name':
                    name = t.get('Value', '')
            if len(name) == 0:
                continue
            self.instances[name] = instance.id

    def _update_reports(self, state, result):
        hostname = result._host.get_name()
        report = self.reports.get(hostname, HostReport())
        report.host = hostname

        if state == STAT_UNREACHABLE:
            report.unreachable = True
            self.reports[hostname] = report
            return

        report.unreachable = False
        report.instance_id = self.instances.get(hostname, '')
        report.inc_stat(state, 1)

        action_args = self._pop_keys_by_prefix(result._task_fields['args'])
        report.add_task(state, str(result._task), str(result._task_fields['action']), action_args)

        print(hostname)
        print(report)
        self.reports[hostname] = report

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self._update_reports(STAT_FAILED, result)

    def v2_runner_on_ok(self, result):
        if result._result['changed']:
            self._update_reports(STAT_CHANGED, result)
        else:
            self._update_reports(STAT_OK, result)

    def v2_runner_on_skipped(self, result):
        self._update_reports(STAT_SKIPPED, result)

    def v2_runner_on_unreachable(self, result):
        self._update_reports(STAT_UNREACHABLE, result)

    def v2_playbook_on_play_start(self, play):
        self.put_event('ansible-run-start', {
            'name': play.get_name().strip(),
            'run_id': run_id,
            'properties': play._ds,
        })
    
    def v2_playbook_on_stats(self, stats):
        for k, v in self.reports.items():
            self.put_event('ansible-run-report', v)

        obj = vars(stats)
        obj['run_id'] = run_id
        self.put_event('ansible-run-end', obj)
