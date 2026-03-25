from datetime import datetime
from typing import Optional, List
import hashlib
import shutil
import os
import requests

from fastapi import FastAPI, UploadFile, Form, File, HTTPException, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from sqlalchemy import create_engine, Column, Integer, String, TIMESTAMP, ForeignKey
from sqlalchemy.orm import declarative_base, sessionmaker, relationship, Session
from pydantic import BaseModel

# CONFIGURACIÓN DE LA APP


app = FastAPI(title="Paquexpress API", version="1.0.0")

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)



DATABASE_URL = "mysql+pymysql://root:@localhost/paquexpress_db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

# -------------------------------------------------------
# MODELOS SQLALCHEMY (TABLAS)
# -------------------------------------------------------

class Agente(Base):
    """Tabla de agentes de entrega."""
    __tablename__ = "agentes"

    id_agente  = Column(Integer, primary_key=True, index=True)
    nombre     = Column(String(100), nullable=False)
    correo     = Column(String(100), unique=True, nullable=False)
    # Contraseña guardada como hash MD5
    password   = Column(String(64), nullable=False)

    # Relación: un agente puede tener muchas entregas
    entregas   = relationship("Entrega", back_populates="agente")


class Paquete(Base):
    """
    Tabla de paquetes asignados.
    Los registros se insertan manualmente en la BD o desde la API de administración.
    """
    __tablename__ = "paquetes"

    id_paquete       = Column(Integer, primary_key=True, index=True)
    direccion_destino = Column(String(255), nullable=False)
    # 'pendiente' | 'entregado'
    estado           = Column(String(20), nullable=False, default="pendiente")

    # Relación opcional: un paquete puede tener una entrega
    entrega          = relationship("Entrega", back_populates="paquete", uselist=False)


class Entrega(Base):
    """Registro de entrega: foto + GPS + fecha."""
    __tablename__ = "entregas"

    id_entrega  = Column(Integer, primary_key=True, index=True)
    id_agente   = Column(Integer, ForeignKey("agentes.id_agente"), nullable=False)
    id_paquete  = Column(Integer, ForeignKey("paquetes.id_paquete"), nullable=False)
    ruta_foto   = Column(String(255), nullable=False)
    latitud     = Column(String(50), nullable=False)
    longitud    = Column(String(50), nullable=False)
    direccion   = Column(String(255))
    fecha       = Column(TIMESTAMP, default=datetime.utcnow)

    agente      = relationship("Agente", back_populates="entregas")
    paquete     = relationship("Paquete", back_populates="entrega")


# Crea las tablas si no existen
Base.metadata.create_all(bind=engine)


# MODELOS PYDANTIC 


class AgenteSchema(BaseModel):
    id_agente: int
    nombre: str
    correo: str

    class Config:
        from_attributes = True


class PaqueteSchema(BaseModel):
    id_paquete: int
    direccion_destino: str
    estado: str

    class Config:
        from_attributes = True


class EntregaSchema(BaseModel):
    id_entrega: int
    id_agente: int
    id_paquete: int
    ruta_foto: str
    latitud: str
    longitud: str
    direccion: Optional[str]
    fecha: Optional[datetime]

    class Config:
        from_attributes = True


class LoginModel(BaseModel):
    correo: str
    password: str


class CrearAgenteModel(BaseModel):
    nombre: str
    correo: str
    password: str  # Se encriptará en MD5


class CrearPaqueteModel(BaseModel):
    direccion_destino: str
    estado: str = "pendiente"  # Por defecto 'pendiente'


def md5_hash(password: str) -> str:
    return hashlib.md5(password.encode()).hexdigest()


def get_db():
    """Dependencia de sesión de BD para los endpoints."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def obtener_direccion(lat: str, lon: str) -> str:
    """
    Geocodificación inversa con Nominatim (OpenStreetMap).
    Devuelve la dirección legible o un mensaje de error.
    """
    url = (
        f"https://nominatim.openstreetmap.org/reverse"
        f"?lat={lat}&lon={lon}&format=json"
    )
    headers = {"User-Agent": "paquexpress_app"}
    try:
        resp = requests.get(url, headers=headers, timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            return data.get("display_name", "Sin dirección")
    except Exception:
        pass
    return "No se pudo obtener dirección"



@app.post("/login", summary="Inicio de sesión del agente")
def login(data: LoginModel, db: Session = Depends(get_db)):

    password_hash = md5_hash(data.password)

    agente = db.query(Agente).filter(
        Agente.correo   == data.correo,
        Agente.password == password_hash
    ).first()

    if not agente:
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

    return {
        "login": True,
        "agente": AgenteSchema.from_orm(agente)
    }




@app.get(
    "/paquetes/pendientes",
    response_model=List[PaqueteSchema],
    summary="Lista de paquetes pendientes de entrega"
)
def listar_paquetes_pendientes(db: Session = Depends(get_db)):
    """
    Devuelve todos los paquetes cuyo estado es 'pendiente'.
    El agente seleccionará uno de la lista para registrar su entrega.
    """
    try:
        paquetes = db.query(Paquete).filter(Paquete.estado == "pendiente").all()
        return [PaqueteSchema.from_orm(p) for p in paquetes]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")




@app.post("/entregas/", summary="Registrar evidencia de entrega")
async def registrar_entrega(
    id_agente:  int        = Form(...),
    id_paquete: int        = Form(...),
    latitud:    str        = Form(...),
    longitud:   str        = Form(...),
    file:       UploadFile = File(...),
    db:         Session    = Depends(get_db)
):
   
    paquete = db.query(Paquete).filter(Paquete.id_paquete == id_paquete).first()
    if not paquete:
        raise HTTPException(status_code=404, detail="Paquete no encontrado")
    if paquete.estado == "entregado":
        raise HTTPException(status_code=400, detail="El paquete ya fue entregado")

    try:
        # Guardar foto en disco
        ruta = f"uploads/{file.filename}"
        with open(ruta, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)


        direccion = obtener_direccion(latitud, longitud)


        nueva_entrega = Entrega(
            id_agente  = id_agente,
            id_paquete = id_paquete,
            ruta_foto  = ruta,
            latitud    = latitud,
            longitud   = longitud,
            direccion  = direccion,
            fecha      = datetime.utcnow()
        )
        db.add(nueva_entrega)


        paquete.estado = "entregado"

        db.commit()
        db.refresh(nueva_entrega)

        return {
            "msg":      "Paquete entregado correctamente",
            "entrega":  EntregaSchema.from_orm(nueva_entrega),
            "direccion": direccion
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")




@app.get(
    "/entregas/{id_agente}",
    response_model=List[EntregaSchema],
    summary="Historial de entregas de un agente"
)
def historial_entregas(id_agente: int, db: Session = Depends(get_db)):
    """
    Devuelve todas las entregas realizadas por el agente indicado,
    ordenadas de más reciente a más antigua.
    """
    try:
        entregas = (
            db.query(Entrega)
            .filter(Entrega.id_agente == id_agente)
            .order_by(Entrega.fecha.desc())
            .all()
        )
        return [EntregaSchema.from_orm(e) for e in entregas]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")



@app.get(
    "/agentes/",
    response_model=List[AgenteSchema],
    summary="[ADMIN] Listar todos los agentes registrados"
)
def listar_agentes(db: Session = Depends(get_db)):
    """
    Devuelve la lista completa de agentes registrados en el sistema.
    Útil para verificar registros desde la interfaz de FastAPI (/docs).
    """
    try:
        agentes = db.query(Agente).all()
        return [AgenteSchema.from_orm(a) for a in agentes]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")



@app.post( "/agentes/",response_model=AgenteSchema,)
def crear_agente(data: CrearAgenteModel, db: Session = Depends(get_db)):

    existente = db.query(Agente).filter(Agente.correo == data.correo).first()
    if existente:
        raise HTTPException(status_code=400, detail="El correo ya está registrado")
    try:
        nuevo = Agente(
            nombre   = data.nombre,
            correo   = data.correo,
            password = md5_hash(data.password)
        )
        db.add(nuevo)
        db.commit()
        db.refresh(nuevo)
        return AgenteSchema.from_orm(nuevo)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")




@app.get(
    "/paquetes/",
    response_model=List[PaqueteSchema],
    summary="[ADMIN] Listar todos los paquetes"
)
def listar_paquetes(db: Session = Depends(get_db)):

    try:
        paquetes = db.query(Paquete).all()
        return [PaqueteSchema.from_orm(p) for p in paquetes]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")




@app.post(
    "/paquetes/",
    response_model=PaqueteSchema,
    summary="[ADMIN] Agregar un nuevo paquete"
)
def crear_paquete(data: CrearPaqueteModel, db: Session = Depends(get_db)):
  
    try:
        nuevo = Paquete(
            direccion_destino = data.direccion_destino,
            estado            = data.estado
        )
        db.add(nuevo)
        db.commit()
        db.refresh(nuevo)
        return PaqueteSchema.from_orm(nuevo)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")
