000 MM2S      x DDR=0x10000000 bytes=400
001 MM2S      wq DDR=0x10000190 bytes=656
002 MM2S      wk DDR=0x10000420 bytes=656
003 MM2S      wv DDR=0x100006b0 bytes=656
004 MM2S      wo DDR=0x10000940 bytes=608
005 MM2S      mask DDR=0x10000ba0 bytes=16
006 QUANTIZE  x4, x
007 PROJECT   qfp, x4, wq
008 QUANTIZE  q, qfp
009 PROJECT   kfp, x4, wk
010 QUANTIZE  k, kfp
011 PROJECT   vfp, x4, wv
012 QUANTIZE  v, vfp
013 QK        scores, q, k
014 SOFTMAX   probabilities, scores, mask
015 PV        context, probabilities, v
016 QUANTIZE  context4, context
017 PROJECT   output_fp, context4, wo
018 QUANTIZE  output4, output_fp
019 S2MM      output4 DDR=0x10000bb0 bytes=48
020 END       
