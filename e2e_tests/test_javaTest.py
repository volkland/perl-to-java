import unittest

import requests
from sqlalchemy.orm import Session
from sqlalchemy import create_engine

from db_models.database import Tnb
from helpers.db import clear_all_tables
from db_models import database
from rpc_requests.requests import java_Test_request

class test_javaTest(unittest.TestCase):

    def setUp(self):
        self.database_engine = create_engine(f'mysql+pymysql://root:root@localhost:3308/shareddb',
                                        isolation_level="READ COMMITTED")
        self.sql_session = Session(self.database_engine)

        clear_all_tables(self.database_engine, database.Base)

    def tearDown(self):
        self.sql_session.close()

    def fillDataBase(self):
        tnb_1 = Tnb(tnb='Test_1', name='This is a test')
        tnb_2 = Tnb(tnb='Test_2', name='This is a test')
        tnb_3 = Tnb(tnb='Test_3', name='This is a test')
        self.sql_session.add(tnb_1)
        self.sql_session.add(tnb_2)
        self.sql_session.add(tnb_3)
        self.sql_session.commit()

    def make_post_request(self, payload):
        return requests.post(
            f"http://localhost:8099/jsonrpc",
            json=payload,
            headers={'Content-Type': 'application/json; charset=utf-8'}
        )

    def test_javaTest(self):
        self.fillDataBase()
        response_json = self.make_post_request(java_Test_request).json()

        self.assertEqual('200', response_json['faultCode'])
        self.assertEqual('Method success', response_json['faultString'])
        self.assertEqual({'id': 1, 'output': 'acul has a rather warm day. And he has 3 tnbs'}, response_json['something'])
        print(response_json)