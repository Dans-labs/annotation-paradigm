1: abcde
2: abcfe
3: nbcde
4: nbcdg
5: nbcdh

graph1 (token by token)
 (12)a (12345)b (12345)c (1345)d (123)e
(345)n                      (2)f   (4)g
                                   (5)h 

graph2 (compress by identifying witness sets)
 (12)a (12345)bc (1345)d (123)e
(345)n              (2)f   (4)g
                           (5)h 

[a]-[bc]-[f]-[e]
         [d]-[g]
             [h]

graph3 (hack from 2)
 (12)a (1345)bcd        (123)e
(345)n    (2)bc    (2)f   (4)g
                          (5)h 

1: abc
2: xyc
3: xzc

graph

 (1)a (1)b (123)c
(23)x (2)y
      (3)z

graph (C)

 (1)ab     (123)c
(23)x (2)y
      (3)z
