"""Independent arithmetic checks and failure/state/chunk boundary regressions."""
import ast,math,struct,unittest
from pathlib import Path
import torch
import numeric as num
from isa import *
from interpreter import DDR,Interpreter
from compiler import Compiler

def rn(x): return struct.unpack('<f',struct.pack('<f',x))[0]
def reference_dot(a,b):
    result=0.0
    for start in range(0,len(a),16):
        products=[rn(a[i]*b[i]) if i<len(a) else 0.0 for i in range(start,start+16)]
        while len(products)>1: products=[rn(products[i]+products[i+1]) for i in range(0,len(products),2)]
        result=rn(result+products[0])
    return result

class Contracts(unittest.TestCase):
    def test_independent_FP32_tree_and_tail(self):
        torch.manual_seed(123)
        for k in (1,15,16,17,64,128,1023):
            a=(torch.randn(2,k)*3).to(torch.bfloat16)
            b=torch.randint(-7,8,(3,k),dtype=torch.int8)
            actual=num.dot(a,b)
            expected=torch.tensor([[reference_dot(row.tolist(),col.tolist()) for col in b] for row in a])
            self.assertTrue(torch.equal(actual.view(torch.int32),expected.view(torch.int32)))
    def test_BF16_ties_FTZ_and_W4(self):
        actual=num.bf16(torch.tensor([1.00390625,1.01171875,-1.00390625,1e-40]))
        self.assertEqual(actual.float().tolist(),[1,1.015625,-1,0])
        q=torch.arange(-7,8,dtype=torch.int8).repeat(2)[:16].reshape(1,-1)
        self.assertTrue(torch.equal(q,num.unpack(num.pack(q))))
        with self.assertRaises(ValueError): num.unpack(torch.tensor([[0x08]],dtype=torch.uint8))
        q,s=num.quantize(torch.zeros((2,128),dtype=torch.bfloat16))
        self.assertTrue(torch.equal(s,torch.ones_like(s)));self.assertTrue((q==0).all())
    def test_prefix_encoding_and_reserved_bits(self):
        c=command('DMA_LOAD',a=22,address=0x10000000,btt=256,mode=1,m=1,n=128,flags=BEGIN|FINAL)
        word=int.from_bytes(c.encode(),'little')
        self.assertEqual(word>>252,1);self.assertEqual((word>>247)&31,22)
        self.assertEqual((word>>150)&0xffffffff,0x10000000)
        self.assertEqual(Command.decode(c.encode()),c)
        with self.assertRaises(ValueError): Command.decode((word|1).to_bytes(32,'little'))
        with self.assertRaises(ValueError): command('GEMM',a=0,b=1,c=2,scale=8,m=1,n=128,k=128,flags=INIT,address=8).encode()
        with self.assertRaises(ValueError): command('VECTOR',a=0,c=0,m=1,n=8,mode=VEC['CAST']).encode()
    def test_chunk_capacity_and_DDR_alias_boundary(self):
        chunker=Chunker()
        store=command('DMA_STORE',a=0,address=0x10000000,btt=16,mode=1,m=1,n=8)
        load=command('DMA_LOAD',a=1,address=0x10000000,btt=16,mode=1,m=1,n=8,flags=BEGIN|FINAL)
        self.assertEqual(chunker.push(store),[])
        chunks=chunker.push(load)
        self.assertEqual(chunks,[[store,Command()]])
        self.assertEqual(chunker.flush(),[[load,Command()]])
        for _ in range(1023): self.assertEqual(chunker.push(load),[])
        self.assertEqual(len(chunker.push(load)[0]),1024)
    def test_partial_assembly_failure_and_END_preservation(self):
        sim=Interpreter(DDR())
        sim.put(6,torch.ones((1,8),dtype=torch.bfloat16),1,1)
        c=command('VECTOR',a=6,c=0,m=1,n=8,mode=VEC['LAYOUT'],extent_m=1,extent_n=16,
                  tensor=2,flags=INSERT|BEGIN)
        sim.run_chunk([c,Command()])
        self.assertFalse(sim.desc[0].valid)
        self.assertTrue(sim.desc[6].valid)
        with self.assertRaises(ValueError): sim.get(0)
        bad=command('VECTOR',a=6,c=0,m=1,n=8,mode=VEC['LAYOUT'],col=0,tensor=2,flags=INSERT|FINAL|LAST_A)
        with self.assertRaises(ValueError): sim.execute(bad)
        self.assertFalse(sim.desc[0].valid);self.assertTrue(sim.desc[6].valid)
        # Reinitialize, then complete across a normal END without resetting bank data.
        sim.run_chunk([c,Command()])
        final=command('VECTOR',a=6,c=0,m=1,n=8,mode=VEC['LAYOUT'],col=8,tensor=2,flags=INSERT|FINAL|LAST_A)
        sim.run_chunk([final,Command()])
        self.assertTrue(torch.equal(sim.get(0),torch.ones((1,16),dtype=torch.bfloat16)))
        self.assertFalse(sim.desc[6].valid)
    def test_W4_initial_accumulation_signed_zero(self):
        sim=Interpreter(DDR())
        activation=torch.zeros((1,128),dtype=torch.bfloat16)
        activation[0,0]=torch.finfo(torch.bfloat16).tiny
        codes=torch.zeros((128,128),dtype=torch.int8);codes[:,0]=-1
        scales=torch.full((1,128),torch.finfo(torch.float32).tiny)
        sim.put(6,activation,1,1);sim.put(7,num.pack(codes),3,2);sim.put(8,scales,2,3)
        sim.execute(command('GEMM',a=6,b=7,c=11,scale=8,m=1,n=128,k=128,flags=INIT|FINAL))
        self.assertTrue((sim.get(11).view(torch.int32)==0).all())
        with self.assertRaises(ValueError):
            command('GEMM',a=6,b=7,c=11,scale=8,m=1,n=64,k=128,flags=INIT).encode()
    def test_scope_and_no_PS_tensor_imports(self):
        compiler=Compiler({})
        for tokens,prefix,phase in [([],0,'prefill'),([1]*513,0,'prefill'),([1],1024,'decode'),([1,2],2,'decode'),([151936],0,'prefill')]:
            with self.assertRaises(ValueError): next(compiler.program(tokens,prefix,phase))
        for filename in ('compiler.py','isa.py'):
            tree=ast.parse((Path(__file__).parent/filename).read_text())
            modules=[node.module for node in ast.walk(tree) if isinstance(node,ast.ImportFrom)]
            modules.extend(alias.name for node in ast.walk(tree) if isinstance(node,ast.Import) for alias in node.names)
            self.assertFalse(any(m and m.split('.')[0] in ('torch','numpy','transformers','numeric','interpreter') for m in modules))
    def test_nonlinear_bounds_and_causal_tail(self):
        x=torch.logspace(-20,20,4096)
        self.assertLess(((num.rsqrt(x)-torch.rsqrt(x)).abs()/torch.rsqrt(x)).max().item(),3e-7)
        self.assertLess(((num.reciprocal(x)-x.reciprocal()).abs()/x.reciprocal()).max().item(),3e-7)
        x=torch.linspace(-80,0,4096)
        self.assertLess(((num.exp_nonpositive(x)-x.exp()).abs()/x.exp()).max().item(),6e-6)
        probabilities=num.softmax(torch.zeros((2,17)),15)
        self.assertEqual(probabilities[0,16].item(),0)
        self.assertTrue((probabilities[1]>0).all())

if __name__=='__main__':
    torch.set_num_threads(4)
    unittest.main()
