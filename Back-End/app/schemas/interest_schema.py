from pydantic import BaseModel

from datetime import datetime





class InterestCreate(BaseModel):

    name: str





class InterestResponse(BaseModel):

    id: int

    name: str

    created_at: datetime



    class Config:

        from_attributes = True
