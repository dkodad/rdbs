from sqlalchemy import create_engine, Column, Integer, String, Date, Enum, func, case,Boolean
from sqlalchemy.orm import declarative_base

from sqlalchemy.orm import sessionmaker
from datetime import date,datetime
DATABASE_URL = "mysql+pymysql://root:@localhost/zoodb"
engine = create_engine(DATABASE_URL, echo=True)

Base = declarative_base()


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class Animal(Base):
    __tablename__ = "animals"

    animal_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    species = Column(String(50), nullable=False)
    date_of_birth = Column(Date, nullable=False)
    gender = Column(Enum("Male", "Female"), nullable=False)
    date_of_arrival = Column(Date, nullable=False)




Base.metadata.create_all(engine)

def insert_sample_data():
    session = SessionLocal()
    new_animal = Animal(
        name="Valo",
        species="Lion",
        date_of_birth=date(2012, 1, 20),
        gender="Female",
        date_of_arrival=date(2019, 2, 15),
    )
    session.add(new_animal)
    session.commit()
    session.close()
    print("Data byla přidána!")




def get_all_animals():
    session = SessionLocal()
    animals = session.query(Animal).all()
    for animal in animals:
        print(
            f"{animal.animal_id}: {animal.name} ({animal.species}), narozen: {animal.date_of_birth}"
        )
    session.close()


def get_average_animal_age():
    session = SessionLocal()
    today = date.today()

    avg_age = session.query(
        func.avg(
            (func.year(today) - func.year(Animal.date_of_birth)) -
            case(
                (func.date_format(today, "%m-%d") < func.date_format(Animal.date_of_birth, "%m-%d"), 1),
                else_=0
            )
        )
    ).scalar()

    session.close()
    return round(avg_age, 2) if avg_age is not None else None
def get_average_age_by_species():
    session = SessionLocal()
    today = date.today()

    avg_age_by_species = session.query(
        Animal.species,
        func.avg(
            (func.year(today) - func.year(Animal.date_of_birth)) -
            case(
                (func.date_format(today, "%m-%d") < func.date_format(Animal.date_of_birth, "%m-%d"), 1),
                else_=0
            )
        ).label("average_age")
    ).group_by(Animal.species).all()

    session.close()
    return {species: round(avg_age, 2) for species, avg_age in avg_age_by_species}



# insert_sample_data()
# get_all_animals()
print(f"Průměrný věk zvířat: {get_average_animal_age()} let")
print("\n")
print(f"Průměrný věk zvířat: {get_average_age_by_species()} let")
