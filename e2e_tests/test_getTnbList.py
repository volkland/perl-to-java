import unittest

import requests
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, text

from helpers.db import clear_all_tables
from db_models import database
from helpers.tnbs import tnbs
from rpc_requests.requests import (
    get_tnb_list_no_params_request,
    get_tnb_list_D001_request,
    get_tnb_list_Y123_request,
    get_tnb_list_D905_request
)
from rpc_responses.responses import (test_getTnbList_in_correct_order_no_param_response,test_getTnbList_in_correct_order_D905_param_response)

class test_getTnbList(unittest.TestCase):

    def setUp(self):
        self.database_engine = create_engine(f'mysql+pymysql://root:root@localhost:3308/shareddb',
                                        isolation_level="READ COMMITTED")
        self.sql_session = Session(self.database_engine)

        clear_all_tables(self.database_engine, database.Base)

    def tearDown(self):
        self.sql_session.close()

    def fillDataBase(self):
        for tnb in tnbs:
            new_tnb = database.Tnb(tnb=tnb[0],name=tnb[1])
            self.sql_session.add(new_tnb)
        self.sql_session.commit()

    def make_post_request(self, payload):
        return requests.post(
            f"http://localhost:8099/jsonrpc",
            json=payload,
            headers={'Content-Type': 'application/json; charset=utf-8'}
        )

    def test_getTnbList_contains_200_faultcode(self):
        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('200', response_json['faultCode'])

    def test_getTnbList_contains_correct_faultString(self):
        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('Method success', response_json['faultString'])

    def test_no_param_getTnbList_yields_telekom(self):
        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'name': 'Deutsche Telekom', 'tnb': 'D001', 'isTnb': False,}], response_json['tnbs'])

    def test_getTnbList_with_d001_param_yields_telekom_and_tnb_false(self):
        response_json = self.make_post_request(get_tnb_list_D001_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'name': 'Deutsche Telekom', 'tnb': 'D001', 'isTnb': False,}], response_json['tnbs'])

    def test_getTnbList_with_d001_param_yields_telekom_and_tnb_true(self):
        d001 = database.Tnb(tnb="D001",name="T-Mobile")
        self.sql_session.add(d001)
        self.sql_session.commit()

        response_json = self.make_post_request(get_tnb_list_D001_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'isTnb': True, 'name': 'Deutsche Telekom', 'tnb': 'D001'}, {'isTnb': True, 'name': 'T-Mobile', 'tnb': 'D001'}], response_json['tnbs'])

    def test_getTnbList_with_y123_param_yields_random_carrier_and_tnb_false(self):
        y123 = database.Tnb(tnb="Y123",name="Random Carrier")
        self.sql_session.add(y123)
        self.sql_session.commit()

        response_json = self.make_post_request(get_tnb_list_D001_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'tnb': 'D001', 'isTnb': False, 'name': 'Deutsche Telekom'},{'isTnb': False, 'name': 'Random Carrier', 'tnb': 'Y123'}], response_json['tnbs'])

    def test_getTnbList_with_y123_param_yields_random_carrier_and_tnb_true(self):
        y123 = database.Tnb(tnb="Y123",name="Random Carrier")
        self.sql_session.add(y123)
        self.sql_session.commit()

        response_json = self.make_post_request(get_tnb_list_Y123_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'tnb': 'D001', 'isTnb': False, 'name': 'Deutsche Telekom'},{'isTnb': True, 'name': 'Random Carrier', 'tnb': 'Y123'}], response_json['tnbs'])

    def test_getTnbList_in_correct_order_no_param_request(self):
        self.fillDataBase()

        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual(test_getTnbList_in_correct_order_no_param_response, response_json['tnbs'])

    def test_getTnbList_in_correct_order_D905_param(self):
        self.fillDataBase()

        response_json = self.make_post_request(get_tnb_list_D905_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual(test_getTnbList_in_correct_order_D905_param_response, response_json['tnbs'])

    def test_getTnbList_filter_D146(self):
        y123 = database.Tnb(tnb="Y123",name="Random Carrier")
        d146 = database.Tnb(tnb="D146",name="Filter Me")
        self.sql_session.add(y123)
        self.sql_session.add(d146)
        self.sql_session.commit()

        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'tnb': 'D001', 'isTnb': False, 'name': 'Deutsche Telekom'},{'isTnb': False, 'name': 'Random Carrier', 'tnb': 'Y123'}], response_json['tnbs'])

    def test_getTnbList_filter_D218(self):
        y123 = database.Tnb(tnb="Y123",name="Random Carrier")
        d218 = database.Tnb(tnb="D218",name="Filter Me")
        self.sql_session.add(y123)
        self.sql_session.add(d218)
        self.sql_session.commit()

        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'tnb': 'D001', 'isTnb': False, 'name': 'Deutsche Telekom'},{'isTnb': False, 'name': 'Random Carrier', 'tnb': 'Y123'}], response_json['tnbs'])

    def test_getTnbList_filter_D248(self):
        y123 = database.Tnb(tnb="Y123",name="Random Carrier")
        d248 = database.Tnb(tnb="D248",name="Filter Me")
        self.sql_session.add(y123)
        self.sql_session.add(d248)
        self.sql_session.commit()

        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual([{'tnb': 'D001', 'isTnb': False, 'name': 'Deutsche Telekom'},{'isTnb': False, 'name': 'Random Carrier', 'tnb': 'Y123'}], response_json['tnbs'])

    def test_return_200_with_non_utf8_characters(self):
        # Insert invalid UTF-8 bytes encoded as hex
        invalid_utf8_hex = '8081'  # Represents b'\x80\x81'
        self.sql_session.execute(
            text("INSERT INTO tnbs (tnb, name) VALUES (:tnb, UNHEX(:name))"),
            {'tnb': 'Y123', 'name': invalid_utf8_hex}
        )
        self.sql_session.commit()

        response_json = self.make_post_request(get_tnb_list_no_params_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertIn({"isTnb":False,"name":"Deutsche Telekom","tnb":"D001"}, response_json['tnbs'])
        self.assertTrue(any(entry['tnb'] == 'Y123' for entry in response_json['tnbs']))









