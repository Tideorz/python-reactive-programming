import json
import os
import config as conf

from rx import Observable
from rx.subjects import Subject
from tornado import ioloop
from tornado.escape import json_decode
from tornado.httpclient import AsyncHTTPClient
from tornado.web import Application, RequestHandler, StaticFileHandler, url
from tornado.websocket import WebSocketHandler


AsyncHTTPClient.configure("tornado.curl_httpclient.CurlAsyncHTTPClient")


class WSHandler(WebSocketHandler):
    orgs = conf.orgs

    def check_origin(self, origin):
        # Override to enable support for allowing alternate origins.
        return True

    def get_org_repos(self, org):
        """request the repos to the GitHub API"""
        http_client = AsyncHTTPClient()
        response = http_client.fetch(f"{GIT_ORG}/{org}", headers=headers, method="GET")
        return response

    def on_message(self, message):
        obj = json_decode(message)
        self.subject.on_next(obj['term'])

    def on_close(self):
        # Unsubscribe from observable
        # will stop the work of all observable
        self.combine_latest_sbs.dispose()
        print("WebSocket closed")

    def open(self):
        print("WebSocket opened")
        self.write_message("connection opened")

        def _send_response(x):
            self.write_message(json.dumps(x))

        def _on_error(ex):
            print(ex)

        self.subject = Subject()

        user_input = self.subject.throttle_last(
            1000  # Given the last value in a given time interval
        ).start_with(
            ''  # Immediately after the subscription sends the default value
        ).filter(
            lambda text: not text or len(text) > 2
        )

        interval_obs = Observable.interval(
            60000  # refresh the value every 60 Seconds for periodic updates
        ).start_with(0)

        self.combine_latest_sbs = user_input.combine_latest(
            interval_obs, lambda input_val, i: input_val
        ).do_action(
            lambda x: _send_response('clear')
        ).flat_map(
            self.get_data
        ).subscribe(send_response, _on_error)

    def get_info(self, resp):
        """managing error codes and returning a list of json with content"""
        if resp.code == 200:
            return json.loads(resp.body)
        elif resp.code == 403:
            return {"no_access": 1, "status": "failed"}
        else:
            return {"status": "failed"}

    def get_data(self,query):
        """ query the data to the API and return the content filtered"""
        return Observable.from_list(
            self.orgs
        ).flat_map(
            lambda name: Observable.from_future(self.get_org_repos(name))
        ).flat_map(
            lambda resp: Observable.from_list(
                self.get_info(resp) #transform the response to a json list
             ).filter(
                lambda val: (val.get("description") is not None
            and (val.get("description").lower()).find(query.lower())!= -1)
                    or (val.get("language") is not None
                    and (val.get("language").lower()).find(query.lower())!= -1)
             ).take(10)  #just take 10 repos from each org

        ).map(lambda resp: {'name': resp.get("name"),
        'stars': str(resp.get("stargazers_count")),
        'link': resp.get("svn_url"),'description': resp.get("description"),
        'language': resp.get("language")})
