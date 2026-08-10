#!/usr/bin/python
# -*- coding: utf-8 -*-

import os

import telegram

from utils.debug_utils import print_to_console, LOG_ALL_ERRORS
from utils.file_utils import log_to_file

from enums.status import STATUS
from enums.notifications import NOTIFICATION

MAX_MESSAGE_LENGTH = 4000


def _get_bot():
    """Create the Telegram client from runtime secret injection only."""
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    if not token:
        raise RuntimeError("TELEGRAM_BOT_TOKEN is not configured")
    return telegram.Bot(token=token)


def get_chat_id_by_type(notification_id):
    env_name = {
        NOTIFICATION.ARBITRAGE: "TELEGRAM_CHAT_ID_ARBITRAGE",
        NOTIFICATION.DEBUG: "TELEGRAM_CHAT_ID_DEBUG",
        NOTIFICATION.DEAL: "TELEGRAM_CHAT_ID_DEAL",
    }[notification_id]

    value = os.environ.get(env_name, "").strip()
    if not value:
        raise RuntimeError("{name} is not configured".format(name=env_name))
    return int(value)


def log_error_send_message(func_name, some_message, exception):
    msg = "{func_name} FAILED: {msg} {ee}".format(func_name=func_name, msg=some_message, ee=exception)
    print_to_console(msg, LOG_ALL_ERRORS)
    log_to_file(msg, "telegram.log")


def send_single_message_no_parsing(some_message, notification_type):
    res = STATUS.FAILURE
    try:
        chat_id = get_chat_id_by_type(notification_type)
        _get_bot().send_message(chat_id=chat_id, text=str(some_message), timeout=5, parse_mode=None)
        res = STATUS.SUCCESS
    except Exception as e:
        log_error_send_message("send_single_message_no_parsing", some_message, e)

    return res


def send_single_message(some_message, notification_type):

    if len(some_message) > MAX_MESSAGE_LENGTH:
        some_message = some_message[:MAX_MESSAGE_LENGTH] + "... etc"

    try:
        chat_id = get_chat_id_by_type(notification_type)
        _get_bot().send_message(chat_id=chat_id, text=str(some_message), timeout=5,
                                parse_mode=telegram.ParseMode.HTML)
        res = STATUS.SUCCESS
    except Exception as e:
        log_error_send_message("send_single_message", some_message, e)
        res = send_single_message_no_parsing(some_message, notification_type)

    return res
