# formal grammar of layers
layer = layername layeraddress chunk*
chunk = position? material
material = "[|" (char | positionref)* "|]"
position = [0-9]+
positionref = "<<" (layeraddress ":")? position">>"

# explanation of intended use
* a *passage* in a manuscript is represented by a set of *layers*
* layers contain textual material found in the manuscript
* layers are used to organize information by collecting different kinds of information into different layers
* different kinds are: text versus markup; primary text versus corrections, comments

* in abstracto a layer contains *chunks* of material
* all material in chunks in anchored to *positions*
* a chunk may declare its first position, material in that chunk has its first character at that position, and every subsequent character has a position one higher than the previous character
* if a chunk does not declare its start position, it starts after the end of the previous chunk
* if the first chunk does not declare its start position, it starts at position 0
* every layer has its own positions
* within every chunk of material, you can refer to positions in other layers 
* you can also refer to positions in the same layer; 
1. if you refer from position p to *another* position q in the same layer, the meaning is that p and q are in a sense the same position
2. if you refer from postion p to the same position p in the same layer, it does not add any information, but it does not do harm either; this is useful to mark positions that other layers refer to
3. there is a shortcut: if you refer to a position in a layer, you do not have to mention the layer address
4. more than one character can occur at the same position, you may have several chunks in a layer that start at the same position

# examples
Jude 1:1
SOURCE s 0[|ιουδας ιυ χυ δουλος αδελφος δε ιακωβου τοις εν θω πρι ηγιασμενοις και ιυ χω τετηρημενοις κλητοις|]
NOMSAC n [«s:7»ιυ«s:8»] [«s:10»χυ«s:11»] [«s:10»θω«s:11»] [«s:50»πρ«s:51»] [«s:70»ιυ«s:71»] [«s:73»χω«s:74»]
				«73» <NS>	«75» </NS>	




