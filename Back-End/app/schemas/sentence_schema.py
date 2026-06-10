from pydantic import BaseModel





class SentenceCreate(BaseModel):

    text: str





class SentenceResponse(BaseModel):

    sentenceId: int

    text: str

    wordId: int



    class Config:

        from_attributes = True

