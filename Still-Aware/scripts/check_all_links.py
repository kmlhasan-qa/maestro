#!/usr/bin/env python3
"""Check HTTP links and downloadable files linked from the Still Aware sitemap."""

from concurrent.futures import ThreadPoolExecutor, as_completed
from html.parser import HTMLParser
from http.client import HTTPException
from urllib.error import HTTPError, URLError
from urllib.parse import urldefrag, urljoin, urlsplit
from urllib.request import Request, urlopen
from xml.etree import ElementTree
import socket
import sys


SITE_URL = "https://stillaware.itmanage.com.au"
USER_AGENT = "Mozilla/5.0 (compatible; StillAwareLinkCheck/1.0)"
TIMEOUT_SECONDS = 20
MAX_WORKERS = 8
SAMPLE_BYTES = 32

FILE_SUFFIXES = (
    ".pdf",
    ".zip",
    ".doc",
    ".docx",
    ".xls",
    ".xlsx",
    ".ppt",
    ".pptx",
    ".csv",
)


class AnchorParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.anchors = []
        self.base_href = None
        self.current_anchor = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "base" and attributes.get("href"):
            self.base_href = attributes["href"]
        elif tag == "a" and attributes.get("href"):
            self.current_anchor = (
                attributes["href"],
                "download" in attributes,
            )

    def handle_endtag(self, tag):
        if tag == "a" and self.current_anchor:
            self.anchors.append(self.current_anchor)
            self.current_anchor = None


def fetch(url, headers=None, read_limit=None):
    request_headers = {"User-Agent": USER_AGENT}
    if headers:
        request_headers.update(headers)

    request = Request(url, headers=request_headers)
    with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        body = response.read(read_limit)
        return (
            response.status,
            response.geturl(),
            response.headers,
            body,
        )


def sitemap_pages():
    _, _, _, body = fetch(f"{SITE_URL}/sitemap.xml")
    root = ElementTree.fromstring(body)
    pages = [
        node.text.strip()
        for node in root.iter()
        if node.tag.endswith("loc") and node.text
    ]
    if not pages:
        raise ValueError("The sitemap contained no page URLs.")
    return pages


def linked_http_urls(pages):
    links = {}
    skipped_non_http = set()
    skipped_protected_email = set()

    for page_url in pages:
        _, final_page_url, headers, body = fetch(page_url)
        content_type = headers.get("Content-Type", "").lower()
        if "html" not in content_type:
            raise ValueError(
                f"Sitemap page did not return HTML: {page_url} "
                f"({content_type or 'unknown content type'})"
            )

        parser = AnchorParser()
        parser.feed(body.decode("utf-8", errors="replace"))
        base_url = urljoin(final_page_url, parser.base_href or final_page_url)

        for href, has_download_attribute in parser.anchors:
            target = urljoin(base_url, href)
            parts = urlsplit(target)
            if parts.scheme not in ("http", "https"):
                skipped_non_http.add(target)
                continue
            if parts.path == "/cdn-cgi/l/email-protection":
                skipped_protected_email.add(target)
                continue

            target, _ = urldefrag(target)
            link = links.setdefault(target, {"download": False})
            path = urlsplit(target).path.lower()
            link["download"] |= has_download_attribute or path.endswith(
                FILE_SUFFIXES
            )

    return links, skipped_non_http, skipped_protected_email


def is_download(url, link, headers):
    content_type = headers.get("Content-Type", "").lower()
    disposition = headers.get("Content-Disposition", "").lower()
    return (
        link["download"]
        or urlsplit(url).path.lower().endswith(FILE_SUFFIXES)
        or "attachment" in disposition
        or content_type.startswith("application/pdf")
        or "zip" in content_type
        or "officedocument" in content_type
    )


def check_link(item):
    url, link = item
    try:
        status, final_url, headers, body = fetch(
            url,
            headers={"Range": f"bytes=0-{SAMPLE_BYTES - 1}"},
            read_limit=SAMPLE_BYTES,
        )
    except HTTPError as error:
        unverified = error.code in (401, 403, 408, 425, 429) or error.code >= 500
        return {
            "url": url,
            "state": "unverified" if unverified else "fail",
            "status": error.code,
            "final_url": error.geturl(),
            "download": link["download"],
            "content_type": "",
            "error": f"HTTP {error.code}",
        }
    except (
        URLError,
        TimeoutError,
        socket.timeout,
        HTTPException,
        OSError,
        ValueError,
    ) as error:
        return {
            "url": url,
            "state": "unverified",
            "status": 0,
            "final_url": url,
            "download": link["download"],
            "content_type": "",
            "error": str(error),
        }

    content_type = headers.get("Content-Type", "").lower()
    download = is_download(url, link, headers)
    error = ""

    if not 200 <= status < 300:
        error = f"Unexpected HTTP status {status}"
    elif download:
        path = urlsplit(final_url).path.lower()
        is_pdf = path.endswith(".pdf") or "pdf" in content_type
        is_zip = path.endswith(".zip") or "zip" in content_type
        if is_pdf and not body.startswith(b"%PDF-"):
            error = "Response does not start with a PDF signature"
        elif is_zip and not body.startswith(
            (b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08")
        ):
            error = "Response does not start with a ZIP signature"

    return {
        "url": url,
        "state": "fail" if error else "pass",
        "status": status,
        "final_url": final_url,
        "download": download,
        "content_type": content_type,
        "error": error,
    }


def main():
    pages = sitemap_pages()
    links, skipped_non_http, skipped_protected_email = linked_http_urls(pages)
    results = []

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [
            executor.submit(check_link, item)
            for item in links.items()
        ]
        for future in as_completed(futures):
            results.append(future.result())

    results.sort(key=lambda result: result["url"])
    failures = [result for result in results if result["state"] == "fail"]
    unverified = [result for result in results if result["state"] == "unverified"]
    redirects = [
        result
        for result in results
        if result["url"] != result["final_url"]
    ]
    downloads = [result for result in results if result["download"]]

    print(f"Sitemap pages checked: {len(pages)}")
    print(f"Unique HTTP links checked: {len(results)}")
    print(f"HTTP redirects followed: {len(redirects)}")
    print(f"Download links checked: {len(downloads)}")
    print(f"Non-HTTP links skipped (mailto, tel, etc.): {len(skipped_non_http)}")
    print(f"Cloudflare-protected email links skipped: {len(skipped_protected_email)}")

    print("\nLink results:")
    for result in results:
        detail = f"{result['state'].upper()} {result['status']}: {result['url']}"
        if result["download"]:
            detail += " [download]"
        if result["content_type"]:
            detail += f" [{result['content_type']}]"
        if result["url"] != result["final_url"]:
            detail += f" -> {result['final_url']}"
        if result["error"]:
            detail += f" ({result['error']})"
        print(detail)

    if failures:
        print(f"\nBroken links: {len(failures)}", file=sys.stderr)
        for result in failures:
            print(
                f"FAIL {result['status']}: {result['url']} "
                f"({result['error']})",
                file=sys.stderr,
            )
    if unverified:
        print(
            f"\nLinks blocked or unavailable to this checker: {len(unverified)}",
            file=sys.stderr,
        )
        for result in unverified:
            print(
                f"UNVERIFIED {result['status']}: {result['url']} "
                f"({result['error']})",
                file=sys.stderr,
            )

    if failures or unverified:
        return 1

    print(f"\nAll {len(results)} HTTP links passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
