#!/usr/bin/env python3

import json
import logging
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse, quote
from urllib.request import Request, urlopen


def configure_logging():
    level_name = os.getenv("GO2RTC_DISCOVERY_LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


LOG = logging.getLogger("go2rtc-discovery")


def sanitize_fragment(value, fallback):
    cleaned = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return cleaned or fallback


def api_base():
    return os.getenv("GO2RTC_API", "http://127.0.0.1:1984").rstrip("/")


def timeout_seconds():
    try:
        return int(os.getenv("GO2RTC_DISCOVERY_TIMEOUT", "10"))
    except ValueError:
        return 10


def read_credentials():
    credentials = []

    username = os.getenv("GO2RTC_ONVIF_USERNAME", "")
    password = os.getenv("GO2RTC_ONVIF_PASSWORD", "")
    if username or password:
        credentials.append((username, password))

    raw_list = os.getenv("GO2RTC_ONVIF_CREDENTIALS", "").strip()
    if raw_list:
        for item in raw_list.split(","):
            entry = item.strip()
            if not entry:
                continue
            username, separator, password = entry.partition(":")
            if not separator:
                LOG.warning("Ignoring malformed credential entry: %s", entry)
                continue
            credentials.append((username, password))

    credentials.append((None, None))

    deduped = []
    seen = set()
    for item in credentials:
        if item in seen:
            continue
        seen.add(item)
        deduped.append(item)
    return deduped


def build_url(parsed, username, password):
    host = parsed.hostname or ""
    if ":" in host and not host.startswith("["):
        host = f"[{host}]"

    netloc = host
    if parsed.port is not None:
        netloc = f"{netloc}:{parsed.port}"

    if username is not None:
        userinfo = quote(username, safe="")
        userinfo += ":" + quote(password or "", safe="")
        netloc = f"{userinfo}@{netloc}"

    return urlunparse((parsed.scheme, netloc, parsed.path, parsed.params, parsed.query, parsed.fragment))


def request_json(path, query=None, method="GET"):
    url = api_base() + "/" + path.lstrip("/")
    if query:
        url += "?" + urlencode(query, doseq=True)

    request = Request(url, method=method)
    with urlopen(request, timeout=timeout_seconds()) as response:
        return json.load(response)


def request_sources(path, query=None):
    try:
        payload = request_json(path, query=query)
    except HTTPError as error:
        if error.code == 404:
            return []
        raise

    if isinstance(payload, dict):
        return payload.get("sources", [])
    return []


def candidate_urls(discovered_url, credentials):
    parsed = urlparse(discovered_url)
    return [build_url(parsed, username, password) for username, password in credentials]


def stream_name(source_url, index):
    parsed = urlparse(source_url)
    query = parse_qs(parsed.query)
    host = sanitize_fragment(parsed.hostname or "camera", "camera")
    token = query.get("subtype", [str(index)])[0]
    token = sanitize_fragment(token, str(index))
    prefix = sanitize_fragment(os.getenv("GO2RTC_STREAM_PREFIX", "onvif"), "onvif")
    return f"{prefix}-{host}-{token}"


def import_profiles(discovered_item, credentials):
    discovered_url = discovered_item.get("url", "")
    if not discovered_url:
        return 0

    imported = 0
    profile_items = []
    selected_url = None

    for candidate in candidate_urls(discovered_url, credentials):
        try:
            profile_items = request_sources("api/onvif", {"src": candidate})
        except (HTTPError, URLError) as error:
            LOG.debug("Failed probing %s: %s", candidate, error)
            continue

        if profile_items:
            selected_url = candidate
            break

    if not selected_url:
        LOG.warning("No usable ONVIF profiles for %s", discovered_item.get("name", discovered_url))
        return 0

    for index, profile in enumerate(profile_items):
        profile_url = profile.get("url", "")
        if not profile_url:
            continue

        if "snapshot" in parse_qs(urlparse(profile_url).query):
            continue

        name = stream_name(profile_url, index)
        try:
            request_json("api/streams", {"name": name, "src": profile_url}, method="PUT")
            imported += 1
            LOG.info("Imported %s -> %s", name, profile_url)
        except (HTTPError, URLError) as error:
            LOG.error("Failed importing %s: %s", name, error)

    return imported


def main():
    configure_logging()

    try:
        discovered = request_sources("api/onvif")
    except (HTTPError, URLError) as error:
        LOG.error("Unable to query go2rtc discovery API: %s", error)
        return 1

    if not discovered:
        LOG.info("No ONVIF cameras discovered")
        return 0

    credentials = read_credentials()
    imported = 0
    for item in discovered:
        imported += import_profiles(item, credentials)

    LOG.info("Discovery complete, imported %d stream(s)", imported)
    return 0


if __name__ == "__main__":
    sys.exit(main())