from typing import List, Optional



from pydantic import BaseModel





class QuestionCreate(BaseModel):

    questionText: str

    correctAnswer: str

    options: List[str]

    questionType: Optional[str] = "mcq"





class QuestionResponse(BaseModel):

    questionId: int

    questionText: str

    correctAnswer: str

    options: List[str]

    questionType: Optional[str] = "mcq"



    class Config:

        from_attributes = True

