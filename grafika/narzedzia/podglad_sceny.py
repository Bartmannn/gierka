from PIL import Image, ImageDraw
SP='grafika/podglady/'
def c(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))+(255,)
NOC,ZIEMIA,TAFLA,BRZEG,MGLA,POSW,KS=map(c,["#07080c","#0d0f15","#121926","#1d2738","#3b475a","#6a7f99","#d3dfea"])
B=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]
tree=Image.open('grafika/otoczenie/drzewo.png')
W,H=320,180
s=Image.new('RGBA',(W,H)); p=s.load()
# niebo: ditherowane przejście NOC -> TAFLA -> BRZEG
for y in range(H):
    for x in range(W):
        # poświata nieba wokół księżyca, ciemniej przy krawędziach
        dist=((x-254)**2+((y-26)*1.6)**2)**0.5
        lv=[NOC,TAFLA,BRZEG]
        v=2.6-dist/70+(B[y%4][x%4]/16-0.5)*0.9
        p[x,y]=lv[max(0,min(2,int(v)))]
d=ImageDraw.Draw(s)
d.ellipse((246,18,262,34),fill=KS)
GROUND=134
s.alpha_composite(tree,(96,GROUND-128+2))
d.rectangle((0,GROUND,W,H),fill=ZIEMIA)
# kałuża: odbicie odwrócone, o jeden poziom ciemniejsze, z falami
cx,cy,rx,ry=160,158,118,16
ref=s.crop((0,GROUND-ry*2-40,W,GROUND)).transpose(Image.FLIP_TOP_BOTTOM)
rp=ref.load()
order=[NOC,ZIEMIA,TAFLA,BRZEG,MGLA,POSW,KS]
for y in range(H):
    for x in range(W):
        if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1:
            sy=int((y-(cy-ry))*1.6)  # woda spłaszcza odbicie
            sx=x+(1 if (y//3)%2 else 0)  # drobne falowanie
            if 0<=sy<ref.height and 0<=sx<W:
                col=rp[sx,sy]
                i=order.index(col) if col in order else 2
                col=order[max(0,i-1)]
            else: col=TAFLA
            if y%7==0 and (x//5+y)%4==0 and col!=NOC: col=MGLA  # zmarszczki
            p[x,y]=col
s.save(SP+'scena_1x.png')
s.resize((W*3,H*3),Image.NEAREST).save(SP+'drzewo_w_scenie.png')

# porównanie: szkic | nowe drzewo
sk=Image.open('grafika/szkice/drzewo_szkic.png').convert('RGBA')
skb=Image.new('RGBA',sk.size,(255,255,255,255)); skb.alpha_composite(sk)
tb=Image.new('RGBA',tree.size,BRZEG); tb.alpha_composite(tree)
out=Image.new('RGBA',(128*4*2+24,128*4),NOC)
out.paste(skb.resize((512,512),Image.NEAREST),(0,0)); out.paste(tb.resize((512,512),Image.NEAREST),(536,0))
out.save(SP+'drzewo_porownanie.png')
