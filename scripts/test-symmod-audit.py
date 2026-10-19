#!/usr/bin/env python3
import importlib.util, unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('audit',Path(__file__).with_name('audit-symmod.py'));audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
ROOT=Path(__file__).resolve().parent.parent
class AuditTests(unittest.TestCase):
    def source(self):return audit.parse(ROOT/'Tests/Fixtures/SymMOD/mono.SymMOD')[1]
    def mutate(self,chunks,identifier,offset,value):
        result=[]
        for i,data in chunks:
            if i==identifier:data=bytearray(data);data[offset]=value;data=bytes(data)
            result.append((i,data))
        return result
    def test_exact_and_all_fixtures(self):
        for p in (ROOT/'Tests/Fixtures/SymMOD').glob('*.SymMOD'):
            _,chunks=audit.parse(p);self.assertEqual(audit.compare(chunks,chunks,set()),[])
    def test_opaque_payload_rejected(self):
        a=self.source();b=self.mutate(a,-20,0,99)
        with self.assertRaises(AssertionError):audit.compare(a,b,{-13,-14,-10,-15})
    def test_dsp_flag_and_protected_event_rejected(self):
        a=self.source();b=self.mutate(a,-14,142,2)
        with self.assertRaises(AssertionError):audit.compare(a,b,{-14})
        b=self.mutate(a,-13,0,24)
        with self.assertRaises(AssertionError):audit.compare(a,b,{-13})
    def test_allowed_event_requires_opt_in(self):
        a=self.source();b=self.mutate(a,-13,1,36)
        with self.assertRaises(AssertionError):audit.compare(a,b,set())
        self.assertEqual(audit.compare(a,b,{-13})[0]['changed_bytes'],1)
    def test_malformed_pack_rejected(self):
        for d in [b'PACK\xff\xff',b'PACK\xff\xff\x00\x00\x00\x01\x00\x04abcd',b'PACK\xff\xff\x00\x00\x00\x10\xff']:
            with self.assertRaises(AssertionError):audit.unpack(d)
if __name__=='__main__':unittest.main()
