import os
import unittest
import numpy as np
import tensorflow as tf
import tensorflow.contrib.slim as slim
import sys
from IPython import embed

MPM_module = tf.load_op_library('../../build/libtaichi_differentiable_mpm.so')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'



class MPMOpTest(unittest.TestCase):
    
    def test_forward(self):
    
        print('\n==============\ntest_forward start')
        
        with tf.Session('') as sess:
            x = tf.placeholder(tf.float32, shape = (1, 3, 1))
            v = tf.placeholder(tf.float32, shape = (1, 3, 1))
            C = tf.constant(np.zeros([1, 3, 3, 1]).astype(np.float32))
            f = np.zeros([1, 3, 3, 1]).astype(np.float32)
            f[0, 0, 0, 0] = 1
            f[0, 1, 1, 0] = 1
            f[0, 2, 2, 0] = 1
            F = tf.constant(f)
            xx, vv, CC, FF, PP, grid = MPM_module.mpm(x, v, C, F)
            step = MPM_module.mpm(xx, vv, CC, FF)
            feed_dict = {x: np.array([[[0.5], [0.5], [0.5]]]).astype(np.float32),
                v: np.array([[[0.1], [0.1], [0.1]]]).astype(np.float32)}
            o = sess.run(step, feed_dict = feed_dict)
            a, b, c, d, e, f = o
            print(o)
            print(f.max())
            
                
if __name__ == '__main__':
    unittest.main()
