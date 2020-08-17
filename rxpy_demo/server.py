import asyncio
import json
import os

import config as conf
import rx
from rx import Observable
from rx.operators import buffer, flat_map, last, map
from rx.subject import Subject
from tornado import ioloop
from tornado.escape import json_decode
from tornado.httpclient import AsyncHTTPClient
from tornado.platform.asyncio import AnyThreadEventLoopPolicy
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
        response = http_client.fetch(
            f"{conf.GIT_ORG}/{org}", headers=conf.headers, method="GET"
        )
        return response

    def on_message(self, message):
        obj = json_decode(message)
        print(message)
        self.subject.on_next(obj["term"])

    def on_close(self):
        # Unsubscribe from observable
        # will stop the work of all observable
        self.subject.dispose()
        print("WebSocket closed")

    def open(self):
        print("WebSocket opened")
        self.write_message("connection opened")

        def _send_response(x):
            print(x)
            self.write_message(json.dumps(x))

        def _on_error(ex):
            print(ex)

        self.subject = Subject()
        self.subject.pipe(
            buffer(rx.interval(5.0)), last(), flat_map(self.get_data)
        ).subscribe(on_next=_send_response, on_error=_on_error)

    def get_info(self, resp):
        """managing error codes and returning a list of json with content"""
        if resp.code == 200:
            js_rsp = json.loads(resp.body)
            print(js_rsp)
            return json.loads(resp.body)
        elif resp.code == 403:
            return {"no_access": 1, "status": "failed"}
        else:
            return {"status": "failed"}

    def get_data(self, query):
        """ query the data to the API and return the content filtered"""
        print(f"test {query}")
        return rx.of(self.orgs).pipe(
            flat_map(
                lambda name: print(name) or rx.from_future(self.get_org_repos(name))
            ),
            flat_map(
                lambda rsp: Observable.from_list(
                    self.get_info(rsp)  # transform the response to a json list
                )
                .filter(
                    lambda val: (
                        val.get("description") is not None
                        and (val.get("description").lower()).find(query.lower()) != -1
                    )
                    or (
                        val.get("language") is not None
                        and (val.get("language").lower()).find(query.lower()) != -1
                    )
                )
                .take(10)  # just take 10 repos from each org
            ),
            map(
                lambda rsp: {
                    "name": rsp.get("name"),
                    "stars": str(rsp.get("stargazers_count")),
                    "link": rsp.get("svn_url"),
                    "description": rsp.get("description"),
                    "language": rsp.get("language"),
                }
            ),
        )


class MainHandler(RequestHandler):
    def get(self):
        self.render("index.html")


def main():
    port = os.environ.get("PORT", 8080)
    app = Application(
        [
            url(r"/", MainHandler),
            (r"/ws", WSHandler),
            (r"/static/(.*)", StaticFileHandler, {"path": "/app/rxpy_demo"}),
        ]
    )
    print("Starting server at port: %s" % port)
    asyncio.set_event_loop_policy(AnyThreadEventLoopPolicy())
    app.listen(port)
    ioloop.IOLoop.current().start()


if __name__ == "__main__":
    main()
