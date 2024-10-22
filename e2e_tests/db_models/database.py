# coding: utf-8
from sqlalchemy import Column, String
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()
metadata = Base.metadata


class Tnb(Base):
    __tablename__ = 'tnbs'

    tnb = Column(String(255), primary_key=True)
    name = Column(String(255))