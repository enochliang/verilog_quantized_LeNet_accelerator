import numba as nb
import numpy as np
import json


def getAllParms():
    weightsDict = {}
    shapeDict = {"c1.conv": [6, 1, 5, 5],
                 "c3.conv": [16, 6, 5, 5],
                 "c5.conv": [120, 16, 5, 5],
                 "f6.fc": [84, 120],
                 "output.fc": [10, 84]}
    ArrList = []
    for key in shapeDict:
        Arr = np.loadtxt('./weights/'+key+".weight.csv",
                         delimiter=',').astype(int)
        shape = shapeDict[key]
        Arr = Arr.reshape(([i for i in shape]))
        ArrList.append(Arr)
        weightsDict[key] = Arr
    weightsDict["outputBias"] = np.loadtxt(
        './weights/'+key+".bias.csv", delimiter=',').reshape(([1, 10])).astype(int)

    scalesDict = {}
    with open('scale_hw.json') as json_file:
        scalesDict = json.load(json_file)

    return weightsDict, scalesDict


@nb.jit()
def MaxPool2d(x, kernel_size=2, stride=2):
    # TODO
    N, C, H, W = x.shape
    x_out = np.zeros((N, C, int(((H-kernel_size)/stride)+1),
                     int((W-kernel_size)/stride + 1)), dtype='int32')
    for i in range(N):
        for j in range(C):
            for k in range(int(((H-kernel_size)/stride)+1)):
                for l in range(int((W-kernel_size)/stride + 1)):
                    lt = [ x[i][j][2*k][2*l], x[i][j][2*k][2*l+1], x[i][j][2*k+1][2*l], x[i][j][2*k+1][2*l+1] ]
                    x_out[i][j][k][l]=max(lt)

    return x_out


@nb.jit()
def ReLU(x):
    # TODO
    x = np.maximum(x,0)

    return x

#============================= Linear ===============================
@nb.jit()
def Linear_do_record(psum_range, x, weights, weightsBias=0):
    # TODO
    psum_record_list = []
    H, W = x.shape

    C = weights.shape[0]
    x_out = np.zeros((H, C), dtype='int32')
    

    for h in range(H):
        for w in range(W):
            for c in range(C):
                x_out[h][c] = (x[h][w] * weights[c][w]) + x_out[h][c]
                psum_record_list.append(x_out[h][c])

                if (x_out[h][c]<psum_range[0]):
                    x_out[h][c] = psum_range[0]
                elif (x_out[h][c]>psum_range[1]):
                    x_out[h][c] = psum_range[1]
    
    x_out = weightsBias + x_out
    x_out = np.clip(x_out,psum_range[0],psum_range[1])

    return x_out, psum_record_list

@nb.jit()
def Linear_do_not_record(psum_range, x, weights, weightsBias=0):
    # TODO
    psum_record_list = []
    H, W = x.shape

    C = weights.shape[0]
    x_out = np.zeros((H, C), dtype='int32')
    

    for h in range(H):
        for w in range(W):
            for c in range(C):
                x_out[h][c] = (x[h][w] * weights[c][w]) + x_out[h][c]
                psum_record_list.append(x_out[h][c])

                if (x_out[h][c]<psum_range[0]):
                    x_out[h][c] = psum_range[0]
                elif (x_out[h][c]>psum_range[1]):
                    x_out[h][c] = psum_range[1]
    
    x_out = weightsBias + x_out
    x_out = np.clip(x_out,psum_range[0],psum_range[1])

    return x_out, psum_record_list

def Linear(psum_range, x, weights, weightsBias=0, psum_record=False):
    # TODO
    if psum_record:
        return Linear_do_record(psum_range, x, weights, weightsBias)
    else:
        return Linear_do_not_record(psum_range, x, weights, weightsBias)

    


#=================================== Conv2d ====================================
@nb.jit()
def Conv2d(psum_range, x, weights, out_channels, kernel_size=5, stride=1, bias=False, psum_record=False):
    # TODO
    psum_record_list = []
    N, C, H, W = x.shape
    x_out = np.zeros((N, out_channels, int(((H-kernel_size)/stride)+1),
                     int((W-kernel_size)/stride + 1)), dtype='int32')
    
    for i in range(N):
        for j in range(out_channels):
            for k in range(int(((H-kernel_size)/stride)+1)):
                for l in range(int((W-kernel_size)/stride + 1)):
                    for m in range(kernel_size):
                        for n in range(kernel_size):
                            for c in range(C):
                                x_out[i][j][k][l] = x_out[i][j][k][l] + (weights[j][c][m][n] * x[i][c][(k*stride)+m][(l*stride)+n])
                                if psum_record:
                                    psum_record_list.append(x_out[i][j][k][l])
                                if (x_out[i][j][k][l]<psum_range[0]):
                                    x_out[i][j][k][l] = psum_range[0]
                                elif (x_out[i][j][k][l]>psum_range[1]):
                                    x_out[i][j][k][l] = psum_range[1]

    return x_out, psum_record_list

def ActQuant(x, scale, shiftbits=16):
    x = np.clip(
        np.floor(scale*x).astype('int') >> shiftbits, -128, 127)
    return x
